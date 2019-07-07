//
// License:
//  See end of the file for license information.
//
// API:
//  parse(...)
//    Parses a .ini file and returns it.
//
//  destroy(...)
//    Frees a .ini file.
//
//  add_parser(...)
//    Adds a custom parsing function for a certain type.
//
//  get(...)
//    Returns the value of a key in a section, demarshalled to the desired type (if available).
//
//  remove(...)
//    Removes a key value from a section
//
// Examples:
//  Opening a .ini files, getting a value and destroying it
//    
//    ini_file, ok := parse("path/to/file.ini");
//    defer if ok do destroy(ini_file);
//  
//    val, ok := ini.get(ini_file, "section", "key", int);
//
//    if ok do fmt.printf("Value is an integer: %v\n", val);
//

package ini

import "core:os"
import "core:strings"
import "core:mem"
import "core:strconv"
import "core:unicode/utf8"

Ini_File :: struct {
    keyval: map[string]^map[string]string,
    parse_procs: [dynamic]Parse_Data,
    data: string,
}

Parse_Proc :: #type proc(ini: ^Ini_File, val: string, data: any) -> bool;

Parse_Data :: struct {
    type: typeid,
    p: Parse_Proc,
}

parse :: proc(path: string) -> (^Ini_File, bool) {
    ini_file := new(Ini_File);
    data, ok := os.read_entire_file(path);
    
    ini_file.data = string(data);
    
    getline :: proc(str: string) -> (string, string) {
        last_was_r := false;
        for c, i in str {
            switch (c) {
                case '\r':
                    // Check if these are consecutive \r's
                    if last_was_r {
                        return str[:i - 1], str[i:];
                    }
                    
                    last_was_r = true;
                    
                case '\n':
                    // This will trigger in case of \n or \r\n
                    return str[:i], str[i+1:];
                    
                case:
                    // If we didn't get a \n we've already got the end of the line
                    if last_was_r do return str[:i-1], str[i:];
            }
        }
        
        return str, "";
    }
    
    current_section := "";
    
    line, remainder := getline(ini_file.data);
    for {
        defer line, remainder = getline(remainder);
    
        line = strings.trim_space(line);
        if len(line) == 0 do continue;
        
        first, _ := utf8.decode_rune_in_string(line);
        if first == '#' || first == ';' do continue;
        
        last, _ := utf8.decode_last_rune_in_string(line);
        
        if first == '[' && last == ']' {
            current_section = line[1:len(line)-1];
        } else if strings.count(line, "=") == 1 {
            // @TODO: do we want to support \=?
            index := strings.index(line, "=");
            
            key := line[:index];
            val := line[index+1:];
            
            // Check if the section exists
            if !(current_section in ini_file.keyval) {
                ini_file.keyval[current_section] = new(map[string]string);
                ini_file.keyval[current_section]^ = make(map[string]string);
            }
            
            section_map := ini_file.keyval[current_section];
            section_map^[key] = val;
        }
        
        if len(remainder) == 0 do break;
    }
    
    return ini_file, ok;
}

destroy :: proc(ini: ^Ini_File) {
    for key, section in ini.keyval {
        delete(section^);
        mem.free(section);
    }
    delete(ini.keyval);
    delete(ini.parse_procs);
    delete(ini.data);
    mem.free(ini);
}

add_parser :: proc(ini: ^Ini_File, $T: typeid, p: Parse_Proc, overwrite := true) -> bool {
    index := -1;
    for p, i in ini.parse_procs {
        if p.type == typeid_of(T) {
            if !overwrite do return false;
            
            index = i;
            break;
        }
    }
    
    data := Parse_Data{typeid_of(T), p};
    
    if index == -1 do append(&ini.parse_procs, data);
    else do ini.parse_procs[index] = data;
    
    return true;
}

get :: proc { get_type_no_section, get_type_with_section, get_any_no_section, get_any_with_section };

get_type_no_section :: proc(ini: ^Ini_File, key: string, $T: typeid) -> (T, bool) {
    return get_type_with_section(ini, "", key, T);
}

get_type_with_section :: proc(ini: ^Ini_File, section: string, key: string, $T: typeid) -> (T, bool) {
    tmp: T = ---;
    ok := get_any_with_section(ini, section, key, tmp);
    return tmp, ok;
}

get_any_no_section :: proc(ini: ^Ini_File, key: string, data: any) -> bool {
    return get_any_with_section(ini, "", key, data);
}

get_any_with_section :: proc(ini: ^Ini_File, section: string, key: string, data: any) -> bool {
    if !(section in ini.keyval) || !(key in ini.keyval[section]^) do return false;

    section_map := ini.keyval[section];

    switch data.id {
        case string:
            // @TODO: restore escape sequences?
            tmp := section_map^[key];
            mem.copy(data.data, &tmp, size_of(string));
            
        // @TODO: more int types?
        case int:
            tmp := strconv.parse_int(section_map^[key]);
            mem.copy(data.data, &tmp, size_of(int));
            
        case uint:
            tmp := strconv.parse_uint(section_map^[key], 10);
            mem.copy(data.data, &tmp, size_of(uint));
            
        case f32:
            tmp := strconv.parse_f32(section_map^[key]);
            mem.copy(data.data, &tmp, size_of(f32));
            
        case f64:
            tmp := strconv.parse_f64(section_map^[key]);
            mem.copy(data.data, &tmp, size_of(f64));
            
        case bool:
            val := section_map^[key];
            tmp := val == "1" || val == "true";
            mem.copy(data.data, &tmp, size_of(bool));
            
        case:
            // Check if we have a user-defined procedure to parse this type
            for p in ini.parse_procs {
                if p.type == data.id {
                    val := section_map^[key];
                    return p.p(ini, val, data);
                }
            }
            
            // No appropiate proc found
            return false;
    }

    return true;
}

remove :: proc { remove_no_section, remove_with_section };

remove_no_section :: proc(ini: ^Ini_File, key: string) {
    remove_with_section(ini, "", key);
}

remove_with_section :: proc(ini: ^Ini_File, section: string, key: string) {
    if !(section in ini.keyval) || !(key in ini.keyval[section]^) do return;
    
    section_map := ini.keyval[section];
    delete_key(section_map, key);
}

// ZLIB LICENSE
//  
//  Copyright (c) 2019 Tom Mol
//  
//  This software is provided 'as-is', without any express or implied
//  warranty. In no event will the authors be held liable for any damages
//  arising from the use of this software.
//  
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//  
//  1. The origin of this software must not be misrepresented; you must not
//     claim that you wrote the original software. If you use this software
//     in a product, an acknowledgment in the product documentation would be
//     appreciated but is not required.
//  2. Altered source versions must be plainly marked as such, and must not be
//     misrepresented as being the original software.
//  3. This notice may not be removed or altered from any source distribution.
//