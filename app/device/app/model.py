# model.py
from dataclasses import dataclass
from typing import Any


@dataclass
class Device:
    alias: str
    uuid: str

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Device":
        try:
            return cls(
                alias=data["alias"],
                uuid=data["device_uuid"],
            )
        except KeyError as exc:
            raise ValueError(f"Missing required device field: {exc}") from exc
