# Third-party notices

This project includes third-party test data. No third-party *implementation*
code is copied, translated, or adapted.

## HTTP Working Group `structured-field-tests`

- **Source:** https://github.com/httpwg/structured-field-tests
- **Pinned revision:** commit `1e280c3ed9ffe0ca5fdb1d97219dddc389007677`
  (fetched 2026-08-04)
- **Files used:** the JSON vectors in `testdata/httpwg/` (see
  `testdata/httpwg/SOURCE.json` for per-file SHA-256 hashes).
- **License:** The repository is licensed under the MIT license
  (`testdata/httpwg/LICENSE.md`).

### License text (MIT)

```
MIT License

Copyright (c) 2019 HTTP Working Group

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## RFC 9651

RFC 9651 ("Structured Field Values for HTTP") is an IETF Standards Track
document. It is used here as a specification reference only; its text is not
included in this repository except for short quotes in documentation.

## What is NOT included

No implementation code from any other Structured Fields project is copied,
translated, or rewritten. The parser, serializer, decimal arithmetic, and
test harness in this repository are original implementations written against
RFC 9651 and verified against the official test vectors above.
