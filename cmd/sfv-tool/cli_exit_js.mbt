// JS exit-code support for `sfv-tool`.

///|
#cfg(target="js")
extern "js" fn cli_process_exit_js(code : Int) -> Unit =
  #| function(code) {
  #|   if (typeof process !== "undefined" && typeof process.exit === "function") {
  #|     process.exit(code);
  #|   }
  #|   throw new Error("exit " + code);
  #| }

///|
/// Terminates the process with the given exit code (Node.js).
#cfg(target="js")
fn cli_exit(code : Int) -> Unit {
  cli_process_exit_js(code)
}
