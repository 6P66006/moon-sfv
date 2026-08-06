# Specification map

RFC 9651 sections to source files and tests. "Parse" refers to §4.2,
"Serialize" to §4.1.

## Grammar / type overview (§3)

| RFC §3 | Topic                       | Source                           | Tests                          |
|--------|-----------------------------|----------------------------------|--------------------------------|
| 3.1    | Lists                       | `model.mbt`, `parser_list.mbt`, `serializer_list.mbt` | `parser_list_test.mbt`, `serializer_test.mbt` |
| 3.1.1  | Inner Lists                 | `model.mbt`, `parser_inner_list.mbt`, `serializer_list.mbt` | `parser_list_test.mbt` |
| 3.1.2  | Parameters                  | `model.mbt`, `ordered_map.mbt`, `parser_parameters.mbt`, `serializer_common.mbt` | `model_test.mbt`, `parser_item_test.mbt` |
| 3.2    | Dictionaries                | `model.mbt`, `ordered_map.mbt`, `parser_dictionary.mbt`, `serializer_dictionary.mbt` | `parser_dictionary_test.mbt`, `serializer_test.mbt` |
| 3.3.1  | Integers                    | `parser_bare_item.mbt`, `serializer_bare_item.mbt` | `parser_item_test.mbt`, `serializer_test.mbt` |
| 3.3.2  | Decimals                    | `decimal.mbt`, `parser_bare_item.mbt`, `serializer_bare_item.mbt` | `decimal_test.mbt` |
| 3.3.3  | Strings                     | `parser_bare_item.mbt`, `serializer_bare_item.mbt` | `parser_item_test.mbt`, `serializer_test.mbt` |
| 3.3.4  | Tokens                      | `parser_bare_item.mbt`, `serializer_bare_item.mbt` | `parser_item_test.mbt` |
| 3.3.5  | Byte Sequences              | `base64.mbt`, `parser_bare_item.mbt`, `serializer_bare_item.mbt` | `parser_item_test.mbt`, `invalid_input_test.mbt` |
| 3.3.6  | Booleans                    | `parser_bare_item.mbt`, `serializer_bare_item.mbt` | `parser_item_test.mbt` |
| 3.3.7  | Dates                       | `parser_bare_item.mbt`, `serializer_bare_item.mbt` | `parser_item_test.mbt` |
| 3.3.8  | Display Strings (erratum 8869) | `percent_encoding.mbt`, `parser_bare_item.mbt`, `serializer_bare_item.mbt` | `parser_item_test.mbt`, `serializer_test.mbt` |

## Serializing (§4.1)

| RFC §4.1  | Topic                    | Source                              | Tests                                |
|-----------|--------------------------|-------------------------------------|--------------------------------------|
| 4.1 (1-7) | top-level algorithm     | `serializer_item.mbt`, `serializer_list.mbt`, `serializer_dictionary.mbt` | `serializer_test.mbt`, `roundtrip_test.mbt` |
| 4.1.1     | List                     | `serializer_list.mbt`               | `serializer_test.mbt`                |
| 4.1.1.1   | Inner List               | `serializer_list.mbt`               | `serializer_test.mbt`                |
| 4.1.1.2   | Parameters               | `serializer_common.mbt`             | `serializer_test.mbt`                |
| 4.1.1.3   | Key                      | `serializer_common.mbt`             | `serializer_test.mbt`                |
| 4.1.2     | Dictionary               | `serializer_dictionary.mbt`         | `serializer_test.mbt`                |
| 4.1.3     | Item                     | `serializer_item.mbt`               | `serializer_test.mbt`                |
| 4.1.3.1   | Bare Item                | `serializer_bare_item.mbt`          | `serializer_test.mbt`                |
| 4.1.4     | Integer                  | `serializer_bare_item.mbt`          | `serializer_test.mbt`                |
| 4.1.5     | Decimal (rounding)       | `decimal.mbt`, `serializer_bare_item.mbt` | `decimal_test.mbt`, `serializer_test.mbt` |
| 4.1.6     | String                   | `serializer_bare_item.mbt`          | `serializer_test.mbt`                |
| 4.1.7     | Token                    | `serializer_bare_item.mbt`          | `serializer_test.mbt`                |
| 4.1.8     | Byte Sequence            | `serializer_bare_item.mbt`          | `serializer_test.mbt`                |
| 4.1.9     | Boolean                  | `serializer_bare_item.mbt`          | `serializer_test.mbt`                |
| 4.1.10    | Date                     | `serializer_bare_item.mbt`          | `serializer_test.mbt`                |
| 4.1.11    | Display String           | `serializer_bare_item.mbt`          | `serializer_test.mbt`                |

## Parsing (§4.2)

| RFC §4.2  | Topic                    | Source                              | Tests                                |
|-----------|--------------------------|-------------------------------------|--------------------------------------|
| 4.2 (1-8) | top-level field algorithm | `parser_common.mbt`                | `parser_item_test.mbt`, `invalid_input_test.mbt` |
| 4.2.1     | List                     | `parser_list.mbt`                   | `parser_list_test.mbt`               |
| 4.2.1.1   | Item or Inner List       | `parser_common.mbt`                 | `parser_list_test.mbt`               |
| 4.2.1.2   | Inner List               | `parser_inner_list.mbt`             | `parser_list_test.mbt`               |
| 4.2.2     | Dictionary               | `parser_dictionary.mbt`             | `parser_dictionary_test.mbt`         |
| 4.2.3     | Item                     | `parser_item.mbt`                   | `parser_item_test.mbt`               |
| 4.2.3.1   | Bare Item                | `parser_bare_item.mbt`              | `parser_item_test.mbt`               |
| 4.2.3.2   | Parameters               | `parser_parameters.mbt`             | `parser_item_test.mbt`               |
| 4.2.3.3   | Key                      | `parser_common.mbt`                 | `parser_dictionary_test.mbt`         |
| 4.2.4     | Integer or Decimal       | `parser_bare_item.mbt`              | `parser_item_test.mbt`, `decimal_test.mbt` |
| 4.2.5     | String                   | `parser_bare_item.mbt`              | `parser_item_test.mbt`               |
| 4.2.6     | Token                    | `parser_bare_item.mbt`              | `parser_item_test.mbt`               |
| 4.2.7     | Byte Sequence            | `parser_bare_item.mbt`              | `parser_item_test.mbt`               |
| 4.2.8     | Boolean                  | `parser_bare_item.mbt`              | `parser_item_test.mbt`               |
| 4.2.9     | Date                     | `parser_bare_item.mbt`              | `parser_item_test.mbt`               |
| 4.2.10    | Display String           | `parser_bare_item.mbt`              | `parser_item_test.mbt`               |

## Multi-line fields and canonicalization

| RFC §4.2 "combine all field lines" / §5.2 HTTP | Source                | Tests                    |
|------------------------------------------------|-----------------------|--------------------------|
| Multi-line combination                          | `field_lines.mbt`     | `field_lines_test.mbt`   |
| Canonical form / round-trip                     | `canonicalize.mbt`    | `roundtrip_test.mbt`     |

## Conformance

| Topic                          | Source                                  | Tests                      |
|--------------------------------|-----------------------------------------|----------------------------|
| Official vector data (generated)| `httpwg_conformance_data*.mbt`          | `conformance_test.mbt`     |
| Conformance runner              | `conformance.mbt`                       | `conformance_test.mbt`     |
| Import script / provenance      | `scripts/import_httpwg_tests.py`, `testdata/httpwg/SOURCE.json` | `scripts/verify_httpwg_snapshot.py` |
