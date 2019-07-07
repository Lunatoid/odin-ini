
package main

import "core:fmt"
import "core:strconv"
import "core:mem"

import "ini"

parse_u32 :: proc(ini_file: ^ini.Ini_File, val: string, data: any) -> bool {
    tmp := u32(strconv.parse_u64(val));
    mem.copy(data.data, &tmp, size_of(u32));
    
    return true;
}

main :: proc() {
    ini_file, success := ini.parse("test.ini");
    defer if success do ini.destroy(ini_file);
    
    if !success do return;
    
    ini.add_parser(ini_file, u32, parse_u32);
    
    val, ok := ini.get(ini_file, "section", "int", u32);
    
    if ok do fmt.printf("> %v\n", val);
    else do fmt.printf("> 'int' not in map\n");
    
    ini.remove(ini_file, "section", "int");
    val, ok = ini.get(ini_file, "section", "int", u32);
    
    if ok do fmt.printf("> %v\n", val);
    else do fmt.printf("> 'int' not in map\n");
}
