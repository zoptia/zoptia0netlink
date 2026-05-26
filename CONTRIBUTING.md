# Contributing to zoptia0netlink

Thank you for your interest in contributing to zoptia0netlink. This document provides guidelines and instructions for contributing.

## Building

Build the library with:

```sh
zig build
```

The minimum supported Zig version is 0.16.0.

## Testing

There are several ways to run the test suite:

- **Unit tests only** (no root required):

  ```sh
  ./test.sh unit
  ```

- **All tests** including integration tests (requires root for netlink operations):

  ```sh
  ./test.sh
  ```

- **Build-system tests**:

  ```sh
  zig build test
  ```

Please make sure all tests pass before submitting a pull request.

## Code Style

- Follow the existing patterns in the codebase.
- Define error sets per module (see `link.zig`, `addr.zig`, `route.zig`, `neigh.zig` for examples).
- Use an explicit allocator parameter for list/query operations that return allocated data.
- Use `page_allocator` for mutation operations (add, delete, set).
- Keep public API surfaces minimal and well-documented.

## Submitting a Pull Request

1. Fork the repository and create a feature branch from `main`.
2. Make your changes, following the code style guidelines above.
3. Add or update tests to cover your changes.
4. Ensure `./test.sh unit` passes without root, and `./test.sh all` passes with root if your changes affect netlink operations.
5. Write a clear description of what your PR changes and why.
6. Submit the pull request against `main`.

### PR Checklist

- [ ] Changes are described clearly in the PR description.
- [ ] New or updated tests are included.
- [ ] `./test.sh unit` passes.
- [ ] `./test.sh all` passes (with root).
- [ ] Code follows existing patterns and conventions.

## Reporting Issues

When opening an issue, please include:

- A clear and descriptive title.
- Steps to reproduce the problem (if applicable).
- Expected behavior vs. actual behavior.
- Your Zig version (`zig version`) and Linux kernel version (`uname -r`).
- Any relevant error messages or log output.

For security vulnerabilities, do **not** open a public issue. See [SECURITY.md](SECURITY.md) for responsible disclosure instructions.

## License

By contributing to zoptia0netlink, you agree that your contributions will be licensed under the Apache License 2.0.
