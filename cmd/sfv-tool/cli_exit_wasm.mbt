// WASM exit-code support for `sfv-tool`.

///|
#cfg(target="wasm")
fn cli_exit_impl(code : Int) -> Unit = "wasi_snapshot_preview1" "proc_exit"

///|
#cfg(target="wasm-gc")
fn cli_exit_impl(code : Int) -> Unit = "__moonbit_sys_unstable" "exit"

///|
/// Terminates the process with the given exit code.
#cfg(any(target="wasm", target="wasm-gc"))
fn cli_exit(code : Int) -> Unit {
  cli_exit_impl(code)
}
