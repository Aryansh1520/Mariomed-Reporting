from typing import Literal

from pydantic import BaseModel, Field, field_validator

# The service area sits roughly between these, so a point far outside is a mistake.
LON_RANGE = (72.0, 75.0)
LAT_RANGE = (18.0, 21.0)

Point = tuple[float, float]
Rings = list[list[Point]]


def _clean_name(value: str) -> str:
    stripped = value.strip()
    if not stripped:
        raise ValueError("Enter a name.")
    return stripped


def _check_points(value: list[Point]) -> list[Point]:
    for lon, lat in value:
        if not (LON_RANGE[0] <= lon <= LON_RANGE[1] and LAT_RANGE[0] <= lat <= LAT_RANGE[1]):
            raise ValueError("Points must be on the map.")
    return value


class TerritoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    kind: Literal["zone", "subzone"]
    parent_id: int | None = None
    points: list[Point] | None = Field(default=None, min_length=3, max_length=500)

    @field_validator("name")
    @classmethod
    def _check_name(cls, value: str) -> str:
        return _clean_name(value)

    @field_validator("points")
    @classmethod
    def _check_points_on_map(cls, value: list[Point] | None) -> list[Point] | None:
        return None if value is None else _check_points(value)


class TerritoryUpdate(BaseModel):
    """Renames a territory, reshapes it, or both. A field left out keeps its current value."""

    name: str | None = Field(default=None, min_length=1, max_length=120)
    points: list[Point] | None = Field(default=None, min_length=3, max_length=500)

    @field_validator("name")
    @classmethod
    def _check_name(cls, value: str | None) -> str | None:
        return None if value is None else _clean_name(value)

    @field_validator("points")
    @classmethod
    def _check_points_on_map(cls, value: list[Point] | None) -> list[Point] | None:
        return None if value is None else _check_points(value)


class TerritoryRead(BaseModel):
    id: int
    name: str
    kind: str
    parent_id: int | None
    color_index: int
    rings: Rings


class MapRegionRead(BaseModel):
    name: str
    kind: str
    rings: Rings


class MapRead(BaseModel):
    regions: list[MapRegionRead]
    territories: list[TerritoryRead]


class SubzoneRef(BaseModel):
    id: int
    name: str
    zone_id: int
    zone_name: str


class UserTerritoriesRead(BaseModel):
    user_id: int
    territory_ids: list[int]


class UserTerritoriesUpdate(BaseModel):
    """The zones and subzones a user is assigned to. Replaces the whole list."""

    territory_ids: list[int] = Field(max_length=500)
