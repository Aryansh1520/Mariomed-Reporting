from sqlalchemy import delete as sql_delete
from sqlalchemy import func, or_, select
from sqlalchemy.orm import Session, aliased

from app.modules.territories.models import MapRegion, Territory, UserTerritory

# Share of a subzone allowed to fall outside its zone. Covers rounding in the shapes.
OUTSIDE_TOLERANCE = 0.001


def list_regions(db: Session) -> list[tuple[MapRegion, str]]:
    rows = db.execute(
        select(MapRegion, func.ST_AsGeoJSON(MapRegion.geom)).order_by(MapRegion.name)
    )
    return [(region, geojson) for region, geojson in rows]


def list_territories(db: Session, ids: set[int] | None) -> list[tuple[Territory, str | None]]:
    """Every active territory when ids is None, otherwise the active ones in ids."""
    query = select(Territory, func.ST_AsGeoJSON(Territory.geom)).where(Territory.is_active.is_(True)).order_by(Territory.id)
    if ids is not None:
        query = query.where(Territory.id.in_(ids))
    return [(territory, geojson) for territory, geojson in db.execute(query)]


def list_territories_by_ids(db: Session, ids: set[int]) -> list[Territory]:
    return list(db.scalars(select(Territory).where(Territory.id.in_(ids))))


def user_ids_assigned_to(db: Session, territory_ids: set[int]) -> set[int]:
    return set(db.scalars(select(UserTerritory.user_id).where(UserTerritory.territory_id.in_(territory_ids))))


def subzone_ids_of_zone(db: Session, zone_id: int) -> set[int]:
    return set(db.scalars(select(Territory.id).where(Territory.parent_id == zone_id)))


def active_subzone_ids(db: Session) -> set[int]:
    """Subzones that are active and sit in an active zone. Only these can be visited."""
    active_zones = select(Territory.id).where(Territory.kind == "zone", Territory.is_active.is_(True))
    return set(
        db.scalars(
            select(Territory.id).where(
                Territory.kind == "subzone",
                Territory.is_active.is_(True),
                Territory.parent_id.in_(active_zones),
            )
        )
    )


def territory_ids_for_user(db: Session, user_id: int) -> set[int]:
    """The active zones and subzones a user is assigned to, plus the active subzones inside an assigned zone."""
    assigned = select(UserTerritory.territory_id).where(UserTerritory.user_id == user_id)
    active_zones = select(Territory.id).where(Territory.kind == "zone", Territory.is_active.is_(True))
    return set(
        db.scalars(
            select(Territory.id).where(
                Territory.is_active.is_(True),
                or_(Territory.parent_id.is_(None), Territory.parent_id.in_(active_zones)),
                or_(Territory.id.in_(assigned), Territory.parent_id.in_(assigned)),
            )
        )
    )


def count_active(db: Session, kind: str) -> int:
    return db.scalar(
        select(func.count()).select_from(Territory).where(Territory.kind == kind, Territory.is_active.is_(True))
    ) or 0


def set_active(db: Session, territory_ids: set[int], is_active: bool) -> None:
    db.execute(
        Territory.__table__.update().where(Territory.id.in_(territory_ids)).values(is_active=is_active)
    )


def assigned_territory_ids(db: Session, user_id: int) -> list[int]:
    return list(db.scalars(select(UserTerritory.territory_id).where(UserTerritory.user_id == user_id).order_by(UserTerritory.territory_id)))


def replace_user_territories(db: Session, user_id: int, territory_ids: list[int]) -> None:
    db.execute(sql_delete(UserTerritory).where(UserTerritory.user_id == user_id))
    db.add_all(UserTerritory(user_id=user_id, territory_id=territory_id) for territory_id in territory_ids)
    db.flush()


def subzone_locations(db: Session, subzone_ids: set[int]) -> list[tuple[int, str, int, str]]:
    """Each subzone with its id, name, zone id and zone name."""
    zone = aliased(Territory)
    query = (
        select(Territory.id, Territory.name, zone.id, zone.name)
        .join(zone, zone.id == Territory.parent_id)
        .where(Territory.id.in_(subzone_ids))
    )
    return [tuple(row) for row in db.execute(query)]


def geojson_of(db: Session, territory_id: int) -> str:
    return db.scalar(select(func.ST_AsGeoJSON(Territory.geom)).where(Territory.id == territory_id))


def get_by_id(db: Session, territory_id: int) -> Territory | None:
    return db.get(Territory, territory_id)


def region_count(db: Session) -> int:
    return db.scalar(select(func.count()).select_from(MapRegion)) or 0


def next_zone_colour(db: Session) -> int:
    highest = db.scalar(select(func.max(Territory.color_index)).where(Territory.kind == "zone"))
    return 0 if highest is None else highest + 1


def clip_to_map(db: Session, wkt: str) -> str | None:
    """Cuts the drawn shape to the map outline. Returns it as GeoJSON, or None when nothing is left inside the map."""
    candidate = func.ST_MakeValid(func.ST_GeomFromText(wkt, 4326))
    union = select(func.ST_Union(MapRegion.geom)).scalar_subquery()
    clipped = func.ST_Multi(func.ST_CollectionExtract(func.ST_Intersection(candidate, union), 3))
    return db.scalar(select(func.ST_AsGeoJSON(clipped)).where(~func.ST_IsEmpty(clipped)))


def share_outside_zone(db: Session, geojson: str, zone_id: int) -> float:
    """The share of the shape that falls outside the zone, from 0 (fully inside) to 1 (fully outside)."""
    shape = func.ST_SetSRID(func.ST_GeomFromGeoJSON(geojson), 4326)
    zone = select(Territory.geom).where(Territory.id == zone_id).scalar_subquery()
    outside = func.ST_Area(func.ST_Difference(shape, zone))
    return db.scalar(select(outside / func.nullif(func.ST_Area(shape), 0))) or 0.0


def geometry_from_geojson(geojson: str) -> object:
    return func.ST_Multi(func.ST_SetSRID(func.ST_GeomFromGeoJSON(geojson), 4326))


def add(db: Session, territory: Territory) -> Territory:
    db.add(territory)
    db.flush()
    return territory


def delete_subzones(db: Session, zone_id: int) -> int:
    """Removes every subzone of the zone. Returns how many were removed."""
    result = db.execute(sql_delete(Territory).where(Territory.parent_id == zone_id))
    return result.rowcount or 0


def set_shape(territory: Territory, geom: object) -> None:
    territory.geom = geom


def delete(db: Session, territory: Territory) -> None:
    db.delete(territory)
