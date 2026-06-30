# typing: ignore
# Stub backend for testing
from typing import Optional
import os


def build_editable(
        wheel_directory: str,
        config_settings: Optional[dict[str, str]],
        metadata_directory=None, # pyright: ignore[reportUnusedParameter,reportMissingParameterType,reportUnknownParameterType]
):
    with open(os.environ["EDITABLE_CONFIG_SETTINGS_RECORD"], "w") as f:
        f.write(repr(config_settings))

    name = "stub-0.0.0-py3-none-any.whl"
    open(os.path.join(wheel_directory, name), "w").close()
    return name
