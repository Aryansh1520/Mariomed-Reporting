from typing import Any

from fastapi import FastAPI
from fastapi.openapi.utils import get_openapi

from app.core.response_envelope import EXCLUDED_PATHS


def _envelope_schema(data_schema: dict[str, Any]) -> dict[str, Any]:
    return {
        "type": "object",
        "required": ["success", "message", "data"],
        "properties": {
            "success": {"type": "boolean"},
            "message": {"type": "string"},
            "data": data_schema,
        },
    }


def enable_envelope_openapi(app: FastAPI) -> None:
    """Make Swagger/OpenAPI document the response envelope for every wrapped route."""

    def custom_openapi() -> dict[str, Any]:
        if app.openapi_schema:
            return app.openapi_schema

        schema = get_openapi(
            title=app.title,
            version=app.version,
            description=app.description,
            routes=app.routes,
        )

        for path, operations in schema.get("paths", {}).items():
            if path in EXCLUDED_PATHS:
                continue
            for operation in operations.values():
                for status_code, response in operation.get("responses", {}).items():
                    json_content = response.get("content", {}).get("application/json")
                    if json_content is None:
                        continue
                    if status_code.startswith(("4", "5")):
                        # Error payloads carry validation or detail info of varying shape.
                        data_schema: dict[str, Any] = {}
                    else:
                        data_schema = json_content.get("schema", {})
                    json_content["schema"] = _envelope_schema(data_schema)

        app.openapi_schema = schema
        return schema

    app.openapi = custom_openapi  # type: ignore[method-assign]
