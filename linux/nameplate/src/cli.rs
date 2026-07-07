use nameplate_core::DaemonCommand;

pub fn parse_command(args: &[String]) -> Result<Option<DaemonCommand>, String> {
    match args.first().map(String::as_str) {
        Some("splash") if args.len() == 1 => Ok(Some(DaemonCommand::Splash)),
        Some("attention") => parse_attention(&args[1..]).map(Some),
        Some("help" | "--help" | "-h") => Ok(None),
        Some(command) => Err(format!("unknown command `{command}`")),
        None => Ok(None),
    }
}

fn parse_attention(args: &[String]) -> Result<DaemonCommand, String> {
    let Some(message) = args.first().filter(|value| !value.starts_with('-')) else {
        return Err("attention requires a message".to_owned());
    };
    let mut title = None;
    let mut duration = None;
    let mut color = None;
    let mut index = 1;
    while index < args.len() {
        let flag = &args[index];
        let value = args
            .get(index + 1)
            .ok_or_else(|| format!("{flag} requires a value"))?;
        match flag.as_str() {
            "--title" => title = Some(value.clone()),
            "--duration" => {
                duration = Some(
                    value
                        .parse::<f64>()
                        .map_err(|_| "--duration must be a number".to_owned())?,
                )
            }
            "--color" => {
                if nameplate_core::normalize_hex(value).is_none() {
                    return Err("--color must be a 3- or 6-digit hex color".to_owned());
                }
                color = Some(value.clone());
            }
            _ => return Err(format!("unknown option `{flag}`")),
        }
        index += 2;
    }
    Ok(DaemonCommand::Attention {
        message: message.clone(),
        title,
        duration,
        color,
    })
}

pub fn print_help() {
    println!(
        "Nameplate for Linux\n\n\
         Usage:\n  nameplate\n  nameplate splash\n  \
         nameplate attention <message> [--title <text>] [--duration <seconds>] [--color <hex>]"
    );
}
