// Native (and LLVM) exit-code support for `sfv-tool`.

///|
#cfg(any(target="native", target="llvm"))
extern "c" fn cli_process_exit(code : Int) = "exit"

///|
/// Terminates the process with the given exit code.
#cfg(any(target="native", target="llvm"))
fn cli_exit(code : Int) -> Unit {
  cli_process_exit(code)
}
