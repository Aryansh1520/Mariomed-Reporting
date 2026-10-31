import json

from sqlalchemy.orm import Session

from app.core.exceptions import BadRequest, NotFound
from app.modules.audit import service as audit
from app.modules.rbac import service as rbac_service
from app.modules.rbac.catalog import Perm, PermissionScope
from app.modules.rbac.principal import Principal
from app.modules.territories import repository
from app.modules.territories.models import Territory
from app.modules.territories.schemas import (
    MapRead,
    MapRegionRead,
    Rings,
    SubzoneRef,
    TerritoryCreate,
    TerritoryRead,
    TerritoryUpdate,
    UserTerritoriesRead,
    UserTerritoriesUpdate,
)
from app.modules.users import service as users_service

OUTSIDE_MAP = "This area is outside the map. Draw it over the service area."
PARENT_NOT_ZONE = "Choose a zone to put this subzone in."
OUTSIDE_ZONE = "Every point of a subzone must sit inside its zone."
NOT_FOUND = "This territory does not exist."
TERRITORY_NOT_FOUND = "One of the zones or subzones does not exist."
USER_NOT_FOUND = "This user does not exist."


def get_map(db: Session, principal: Principal) -> MapRead:
    visible = visible_territory_ids(db, principal, Perm.TERRITORIES_READ)
    return MapRead(
        regions=[
            MapRegionRead(name=region.name, kind=region.kind, rings=_outer_rings(geojson))
            for region, geojson in repository.list_regions(db)
        ],
        territories=[_to_read(territory, geojson) for territory, geojson in repository.list_territories(db, visible)],
    )


def count_active(db: Session, kind: str) -> int:
    return repository.count_active(db, kind)


def active_subzone_ids(db: Session) -> set[int]:
    """The subzones that can be visited: active, inside an active zone."""
    return repository.active_subzone_ids(db)


def visible_territory_ids(db: Session, principal: Principal, code: Perm) -> set[int] | None:
    """Which zones and subzones the caller may see for this permission. None means every one.

    Only an `all` grant sees every territory. Any narrower grant sees the territories assigned to the caller.
    """
    if rbac_service.require_scope(principal, code) == PermissionScope.ALL:
        return None
    return repository.territory_ids_for_user(db, principal.user_id)


def users_assigned_to_subzone(db: Session, subzone_id: int) -> set[int]:
    """Users assigned to the subzone itself or to the zone it sits in."""
    location = subzone_locations(db, {subzone_id}).get(subzone_id)
    if location is None:
        return set()
    return repository.user_ids_assigned_to(db, {subzone_id, location.zone_id})


def subzone_ids_of_zone(db: Session, zone_id: int) -> set[int]:
    return repository.subzone_ids_of_zone(db, zone_id)


def user_territory_ids(db: Session, user_id: int) -> set[int]:
    """The zones and subzones a user is assigned to, for checks made on someone other than the caller."""
    return repository.territory_ids_for_user(db, user_id)


def subzone_locations(db: Session, subzone_ids: set[int]) -> dict[int, SubzoneRef]:
    return {
        subzone_id: SubzoneRef(id=subzone_id, name=name, zone_id=zone_id, zone_name=zone_name)
        for subzone_id, name, zone_id, zone_name in repository.subzone_locations(db, subzone_ids)
    }


def get_user_territories(db: Session, principal: Principal, user_id: int) -> UserTerritoriesRead:
    rbac_service.require_scope(principal, Perm.TERRITORIES_READ)
    if users_service.get_by_id(db, user_id) is None:
        raise NotFound(USER_NOT_FOUND)
    return UserTerritoriesRead(user_id=user_id, territory_ids=repository.assigned_territory_ids(db, user_id))


def set_user_territories(db: Session, principal: Principal, user_id: int, data: UserTerritoriesUpdate) -> UserTerritoriesRead:
    rbac_service.require_scope(principal, Perm.TERRITORIES_MANAGE)
    if users_service.get_by_id(db, user_id) is None:
        raise NotFound(USER_NOT_FOUND)
    territory_ids = sorted(set(data.territory_ids))
    if len(repository.list_territories_by_ids(db, set(territory_ids))) != len(territory_ids):
        raise BadRequest(TERRITORY_NOT_FOUND)
    repository.replace_user_territories(db, user_id, territory_ids)
    audit.record(db, principal.user_id, "user_territories.update", "user", user_id)
    db.commit()
    return UserTerritoriesRead(user_id=user_id, territory_ids=territory_ids)


def create_territory(db: Session, principal: Principal, data: TerritoryCreate) -> TerritoryRead:
    """Creates a zone or subzone by name. A shape is optional; without one it is made on the map later."""
    rbac_service.require_scope(principal, Perm.TERRITORIES_MANAGE)
    clipped = None
    if data.points is not None:
        clipped = repository.clip_to_map(db, _polygon_wkt(data.points))
        if clipped is None:
            raise BadRequest(OUTSIDE_MAP)
    parent_id, colour = _placement(db, data, clipped)
    territory = repository.add(
        db,
        Territory(
            name=data.name,
            kind=data.kind,
            parent_id=parent_id,
            color_index=colour,
            geom=repository.geometry_from_geojson(clipped) if clipped is not None else None,
            is_active=True,
            created_by=principal.user_id,
            updated_by=principal.user_id,
        ),
    )
    audit.record(db, principal.user_id, "territory.create", "territory", territory.id)
    db.commit()
    return _to_read(territory, clipped)


def update_territory(db: Session, principal: Principal, territory_id: int, data: TerritoryUpdate) -> TerritoryRead:
    """Renames a territory, reshapes it, or both. Reshaping leaves its subzones in place."""
    rbac_service.require_scope(principal, Perm.TERRITORIES_MANAGE)
    territory = repository.get_by_id(db, territory_id)
    if territory is None:
        raise NotFound(NOT_FOUND)
    geojson = _reshape(db, territory, data.points) if data.points is not None else None
    if data.name is not None:
        territory.name = data.name
    if geojson is not None:
        repository.set_shape(territory, repository.geometry_from_geojson(geojson))
    territory.updated_by = principal.user_id
    audit.record(db, principal.user_id, "territory.update", "territory", territory.id)
    db.commit()
    current = geojson if geojson is not None else repository.geojson_of(db, territory.id)
    return _to_read(territory, current)


def _reshape(db: Session, territory: Territory, points: list[tuple[float, float]]) -> str:
    """The new shape, cut to the map and checked against the zone it belongs to."""
    clipped = repository.clip_to_map(db, _polygon_wkt(points))
    if clipped is None:
        raise BadRequest(OUTSIDE_MAP)
    if territory.kind == "subzone" and repository.share_outside_zone(db, clipped, territory.parent_id) > repository.OUTSIDE_TOLERANCE:
        raise BadRequest(OUTSIDE_ZONE)
    return clipped


def delete_territory(db: Session, principal: Principal, territory_id: int) -> None:
    """Soft delete: a zone deactivates its subzones too. Their contacts stop appearing and cannot be visited."""
    rbac_service.require_scope(principal, Perm.TERRITORIES_MANAGE)
    territory = repository.get_by_id(db, territory_id)
    if territory is None:
        raise NotFound(NOT_FOUND)
    ids = {territory.id}
    if territory.kind == "zone":
        ids |= subzone_ids_of_zone(db, territory.id)
    repository.set_active(db, ids, False)
    audit.record(db, principal.user_id, "territory.deactivate", "territory", territory.id)
    db.commit()


def _placement(db: Session, data: TerritoryCreate, clipped: str | None) -> tuple[int | None, int]:
    """A zone takes the next colour. A subzone must sit inside an active zone and shares its colour."""
    if data.kind == "zone":
        return None, repository.next_zone_colour(db)
    zone = repository.get_by_id(db, data.parent_id) if data.parent_id is not None else None
    if zone is None or zone.kind != "zone" or not zone.is_active:
        raise BadRequest(PARENT_NOT_ZONE)
    if clipped is not None and repository.share_outside_zone(db, clipped, zone.id) > repository.OUTSIDE_TOLERANCE:
        raise BadRequest(OUTSIDE_ZONE)
    return zone.id, zone.color_index


def _to_read(territory: Territory, geojson: str | None) -> TerritoryRead:
    return TerritoryRead(
        id=territory.id,
        name=territory.name,
        kind=territory.kind,
        parent_id=territory.parent_id,
        color_index=territory.color_index,
        rings=_outer_rings(geojson) if geojson is not None else [],
    )


def _outer_rings(geojson: str) -> Rings:
    """The outer ring of each part of a shape. Holes are not kept, since the map draws outlines."""
    shape = json.loads(geojson)
    parts = [shape["coordinates"]] if shape["type"] == "Polygon" else shape["coordinates"]
    return [[(point[0], point[1]) for point in part[0]] for part in parts]


def _polygon_wkt(points: list[tuple[float, float]]) -> str:
    ring = [*points, points[0]]
    return "POLYGON((" + ", ".join(f"{lon} {lat}" for lon, lat in ring) + "))"
