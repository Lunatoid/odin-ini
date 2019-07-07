# odin-ini
A zlib licensed ini parser written in Odin

## How to use
Using this package is very straightforward.
```
ini_file, ok := parse("path/to/file.ini");
defer if ok do destroy(ini_file);

val, ok := ini.get(ini_file, "section", "key", int);

if ok do fmt.printf("Value is an integer: %v\n", val);
```
Here we parse the .ini file, get the key "key" in the section "section" as an `int`.
The `ok` variable indicates if the key was successfully returned as the desired type.


If you want to parse your own types you can add a custom parse procedure before getting the value.
Here is an example of a `u32` parser:
```
parse_u32 :: proc(ini_file: ^Ini_File, val: string, data: any) -> bool {
    tmp := u32(strconv.parse_u64(val));
    mem.copy(data.data, &tmp, size_of(u32));
    
    return true;
}

// ...

add_parser(ini_file, u32, parse_u32);
```
You get the value as a string and an `any` type which will be the variable that gets returned.
The `typeid` of the `data` is already handled.
