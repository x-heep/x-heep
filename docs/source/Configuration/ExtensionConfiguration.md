# Extension Configuration

X-HEEP can be extended with custom extensions that add functionality to the base system.
These extensions can be also configured using the Python approach of the X-HEEP configuration.

To add an extension to the X-HEEP system, you can use the `add_extension()` method of the `XHeep` class. For example:

```python
from xheep import XHeep

def config():
    system = XHeep(BusType.NtoM)
    ...
    system.add_extension("my_extension", extension_function())

    return system

def extension_function():
    ...
    kwargs = {
        "cpu_fpu": 1,
        ...
    }

    return kwargs
```

The `add_extension()` method takes two parameters:
* `name`: The name of the extension.
* `extension`: An object that represents the extension. This can be any object, such as a dictionary (like in the previous example), a class instance, etc.

Then, from the template files, you can access the extension using the `get_extension()` method of the `XHeep` class. For example:

```
<%
    my_extension = xheep.get_extension("my_extension")
%>
    ...
    localparam int unsigned CpuFpu = 32'd${my_extension["cpu_fpu"]};
    ...
```

The `get_extension()` method takes one parameter `name`, which is the name of the extension to retrieve.
This method returns the extension object associated with the given name, which in the above example is a dictionary.
