# base_peripherals/__init__.py
import pkgutil
import importlib

for _, module_name, _ in pkgutil.iter_modules(__path__, prefix=__name__ + "."):
    module = importlib.import_module(module_name)
    # Import all public (non-underscore) symbols
    for name, obj in module.__dict__.items():
        if not name.startswith("_"):
            globals()[name] = obj
