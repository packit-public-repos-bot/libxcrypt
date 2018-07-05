# Generate crypt-hashes.h from hashes.lst and configure settings.
#
#   Copyright 2018 Zack Weinberg
#
#   This library is free software; you can redistribute it and/or
#    modify it under the terms of the GNU Lesser General Public License
#   as published by the Free Software Foundation; either version 2.1 of
#   the License, or (at your option) any later version.
#
#   This library is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with this library; if not, see
#   <https://www.gnu.org/licenses/>.

BEGIN {
    default_prefix = ":"
    next_output = 0
    error = 0
}

/^#/ {
    next
}

{
    if (!($1 in hash_enabled)) {
        output_order[next_output++] = $1
        hash_enabled[$1] = 0
    }
    if ($1 == ":") {
        printf("%s:%d: name cannot be blank\n", FILENAME, NR)
        error = 1
    }
    if ($4 !~ /^[0-9]+$/ || $4 == 0) {
        printf("%s:%d: nrbytes must be a positive integer\n", FILENAME, NR)
        error = 1
    }
    if ($2 == ":") $2 = ""
    if ($3 == ":") $3 = ""
    if ($5 == ":") $5 = ""

    crypt_fn   = "crypt_" $1 "_rn"
    gensalt_fn = "gensalt_" $1 $2 "_rn"

    if (!(crypt_fn in prototyped)) {
        prototyped[crypt_fn] = 1
        renames[$1] = renames[$1] \
          "#define " crypt_fn " _crypt_" crypt_fn "\n"
        prototypes[$1] = prototypes[$1] \
          "extern void " crypt_fn "\n  " \
          "(const char *, const char *, uint8_t *, size_t, void *, size_t);\n"
    }
    if (!(gensalt_fn in prototyped)) {
        prototyped[gensalt_fn] = 1
        renames[$1] = renames[$1] \
          "#define " gensalt_fn " _crypt_" gensalt_fn "\n"
        prototypes[$1] = prototypes[$1] \
          "extern void " gensalt_fn "\n  " \
          "(unsigned long, const uint8_t *, size_t, uint8_t *, size_t);\n"
    }

    entry = sprintf("  { \"%s\", %d, %s, %s, %d }, \\\n",
                    $3, length($3), crypt_fn, gensalt_fn, $4)
    table_entries[$1] = table_entries[$1] entry

    split($5, flags, ",")
    for (i in flags) {
        flag = flags[i]
        if (flag == "DEFAULT") {
            if (default_prefix == ":") {
                default_hash = $1
                default_prefix = $3
                default_prefix_line = NR
            } else {
                printf("%s:%d: error: 'DEFAULT' specified twice\n",
                       FILENAME, NR) > "/dev/stderr"
                printf("%s:%d: note: previous 'DEFAULT' was here\n",
                       FILENAME, default_prefix_line) > "/dev/stderr"
                error = 1
            }
        } else if (flag == "STRONG" || flag == "GLIBC") {
            # handled in sel-hashes.awk
        } else {
            printf("%s:%d: unrecognized flag %s\n", FILENAME, NR, flag) \
                > "/dev/stderr"
            error = 1
        }
    }
}


END {
    if (error) {
        exit 1
    }

    # ENABLED_HASHES is set on the command line.
    split(ENABLED_HASHES, enabled_hashes_list, ",")
    for (i in enabled_hashes_list) {
        h = enabled_hashes_list[i]
        if (h != "") {
            hash_enabled[h] = 1
        }
    }

    if (default_prefix == ":") {
        print "error: no default hash selected" > "/dev/stderr"
        exit 1
    }

    print "/* Generated by genhashes.awk from hashes.lst.  DO NOT EDIT.  */"
    print ""
    print "#ifndef _CRYPT_HASHES_H"
    print "#define _CRYPT_HASHES_H 1"

    print ""
    for (i in output_order) {
        hash = output_order[i]
        printf("#define INCLUDE_%-8s %d\n", hash, hash_enabled[hash])
    }

    print ""
    print "/* Internal symbol renames for static linkage, see crypt-port.h.  */"
    for (i in output_order) {
        hash = output_order[i]
        if (hash_enabled[hash]) {
            print renames[hash]
        }
    }

    print "/* Prototypes for hash algorithm entry points.  */"
    for (i in output_order) {
        hash = output_order[i]
        if (hash_enabled[hash]) {
            print prototypes[hash]
        }
    }

    print "#define HASH_ALGORITHM_TABLE_ENTRIES \\"
    for (i in output_order) {
        hash = output_order[i]
        if (hash_enabled[hash]) {
            printf("%s", table_entries[hash])
        }
    }
    print "  { 0, 0, 0, 0, 0 }"

    print ""
    if (hash_enabled[default_hash]) {
        print "#define HASH_ALGORITHM_DEFAULT \"" default_prefix "\""
    } else {
        print "#define HASH_ALGORITHM_DEFAULT 0"
    }
    print ""
    print "#endif /* crypt-hashes.h */"
}
