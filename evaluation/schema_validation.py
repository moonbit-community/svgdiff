"""Validation for the complete JSON Schema assertion vocabulary used by svgdiff."""

from typing import Any


SCHEMA_KEYWORDS = {
    "$schema",
    "$id",
    "title",
    "$defs",
    "$ref",
    "type",
    "const",
    "enum",
    "minimum",
    "maximum",
    "minLength",
    "minItems",
    "maxItems",
    "required",
    "properties",
    "additionalProperties",
    "items",
    "anyOf",
}


def audit_schema(schema: Any, path: str = "#") -> None:
    if not isinstance(schema, dict):
        raise ValueError(f"schema at {path} must be an object")
    unknown = set(schema) - SCHEMA_KEYWORDS
    if unknown:
        raise ValueError(
            f"unsupported schema keywords at {path}: {sorted(unknown)}"
        )
    for group in ("$defs", "properties"):
        for name, child in schema.get(group, {}).items():
            audit_schema(child, f"{path}/{group}/{name}")
    if isinstance(schema.get("items"), dict):
        audit_schema(schema["items"], f"{path}/items")
    if isinstance(schema.get("additionalProperties"), dict):
        audit_schema(schema["additionalProperties"], f"{path}/additionalProperties")
    for index, child in enumerate(schema.get("anyOf", [])):
        audit_schema(child, f"{path}/anyOf/{index}")


def resolve_ref(root: dict[str, Any], reference: str) -> dict[str, Any]:
    if not reference.startswith("#/"):
        raise ValueError(f"only local JSON pointers are supported: {reference}")
    current: Any = root
    for encoded in reference[2:].split("/"):
        component = encoded.replace("~1", "/").replace("~0", "~")
        if not isinstance(current, dict) or component not in current:
            raise ValueError(f"unresolved schema reference: {reference}")
        current = current[component]
    if not isinstance(current, dict):
        raise ValueError(f"schema reference does not resolve to an object: {reference}")
    return current


def type_matches(value: Any, type_name: str) -> bool:
    if type_name == "null":
        return value is None
    if type_name == "boolean":
        return isinstance(value, bool)
    if type_name == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if type_name == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if type_name == "string":
        return isinstance(value, str)
    if type_name == "array":
        return isinstance(value, list)
    if type_name == "object":
        return isinstance(value, dict)
    raise ValueError(f"unsupported schema type: {type_name}")


def validate_instance(
    value: Any,
    schema: dict[str, Any],
    root: dict[str, Any],
    path: str = "$",
) -> None:
    if "anyOf" in schema:
        errors = []
        matched = False
        for child in schema["anyOf"]:
            try:
                validate_instance(value, child, root, path)
                matched = True
                break
            except ValueError as error:
                errors.append(str(error))
        if not matched:
            raise ValueError(f"{path}: no anyOf branch matched: {errors}")
    if "$ref" in schema:
        validate_instance(value, resolve_ref(root, schema["$ref"]), root, path)
        return
    if "const" in schema and value != schema["const"]:
        raise ValueError(f"{path}: expected constant {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        raise ValueError(f"{path}: value {value!r} is not in the declared enum")
    declared_type = schema.get("type")
    if declared_type is not None:
        types = declared_type if isinstance(declared_type, list) else [declared_type]
        if not all(isinstance(item, str) for item in types):
            raise ValueError(f"{path}: invalid schema type declaration")
        if not any(type_matches(value, item) for item in types):
            raise ValueError(f"{path}: expected type {types}, got {type(value).__name__}")

    object_declared = declared_type == "object" or (
        isinstance(declared_type, list) and "object" in declared_type
    )
    if isinstance(value, dict) and object_declared:
        required = schema.get("required", [])
        missing = [name for name in required if name not in value]
        if missing:
            raise ValueError(f"{path}: missing required properties {missing}")
        properties = schema.get("properties", {})
        for name, child in properties.items():
            if name in value:
                validate_instance(value[name], child, root, f"{path}.{name}")
        extras = set(value) - set(properties)
        additional = schema.get("additionalProperties", True)
        if additional is False and extras:
            raise ValueError(f"{path}: unexpected properties {sorted(extras)}")
        if isinstance(additional, dict):
            for name in extras:
                validate_instance(value[name], additional, root, f"{path}.{name}")

    array_declared = declared_type == "array" or (
        isinstance(declared_type, list) and "array" in declared_type
    )
    if isinstance(value, list) and array_declared:
        if len(value) < schema.get("minItems", 0):
            raise ValueError(f"{path}: array is shorter than minItems")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            raise ValueError(f"{path}: array is longer than maxItems")
        if isinstance(schema.get("items"), dict):
            for index, item in enumerate(value):
                validate_instance(item, schema["items"], root, f"{path}[{index}]")

    if isinstance(value, str) and len(value) < schema.get("minLength", 0):
        raise ValueError(f"{path}: string is shorter than minLength")
    if (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and "minimum" in schema
        and value < schema["minimum"]
    ):
        raise ValueError(f"{path}: number is below minimum")
    if (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and "maximum" in schema
        and value > schema["maximum"]
    ):
        raise ValueError(f"{path}: number is above maximum")


def schema_accepts(
    value: Any, schema: dict[str, Any], root: dict[str, Any] | None = None
) -> bool:
    try:
        validate_instance(value, schema, schema if root is None else root)
    except ValueError:
        return False
    return True
