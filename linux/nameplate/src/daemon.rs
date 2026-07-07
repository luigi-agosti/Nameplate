use crate::Event;
use nameplate_core::DaemonCommand;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::mpsc;
use std::thread;
use std::time::Duration;

pub fn socket_path() -> Result<PathBuf, String> {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .map(|directory| directory.join("nameplate.sock"))
        .ok_or_else(|| "XDG_RUNTIME_DIR is not set".to_owned())
}

pub fn start_socket_listener(sender: mpsc::Sender<Event>) -> Result<(), String> {
    let path = socket_path()?;
    if path.exists() {
        if UnixStream::connect(&path).is_ok() {
            return Err("another daemon is already running".to_owned());
        }
        fs::remove_file(&path).map_err(|error| error.to_string())?;
    }
    let listener = UnixListener::bind(&path).map_err(|error| error.to_string())?;
    thread::spawn(move || {
        for connection in listener.incoming() {
            let Ok(connection) = connection else { continue };
            let reader = BufReader::new(connection);
            for line in reader.lines() {
                match line.map_err(|error| error.to_string()).and_then(|line| {
                    serde_json::from_str::<DaemonCommand>(&line).map_err(|e| e.to_string())
                }) {
                    Ok(command) => {
                        if sender.send(Event::Command(command)).is_err() {
                            return;
                        }
                    }
                    Err(error) => eprintln!("nameplate: bad socket request: {error}"),
                }
            }
        }
    });
    Ok(())
}

pub fn send_to_daemon(command: &DaemonCommand) -> Result<(), String> {
    let path = socket_path()?;
    let mut stream = match UnixStream::connect(&path) {
        Ok(stream) => stream,
        Err(_) => {
            spawn_daemon()?;
            let mut connection = None;
            for _ in 0..50 {
                thread::sleep(Duration::from_millis(60));
                if let Ok(stream) = UnixStream::connect(&path) {
                    connection = Some(stream);
                    break;
                }
            }
            connection.ok_or_else(|| "daemon did not create its socket".to_owned())?
        }
    };
    let payload = serde_json::to_string(command).map_err(|error| error.to_string())?;
    writeln!(stream, "{payload}").map_err(|error| error.to_string())
}

fn spawn_daemon() -> Result<(), String> {
    use std::os::unix::process::CommandExt;
    let executable = std::env::current_exe().map_err(|error| error.to_string())?;
    let mut command = Command::new(executable);
    command
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null());
    // SAFETY: setsid is async-signal-safe and does not access parent memory.
    unsafe {
        command.pre_exec(|| {
            if libc::setsid() < 0 {
                return Err(std::io::Error::last_os_error());
            }
            Ok(())
        });
    }
    command.spawn().map_err(|error| error.to_string())?;
    Ok(())
}

pub fn remove_socket() {
    if let Ok(path) = socket_path() {
        let _ = fs::remove_file(path);
    }
}
