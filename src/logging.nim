import terminal
import strformat

type LogLevel = ref object of RootObj
    name: string
    colour: ForegroundColor
# TODO convert to a template
proc echo*(this: LogLevel, message: string) = 
    stdout.styledWriteLine(this.colour, fmt"{this.name}: {message}")

let Error*: LogLevel = LogLevel(name: "ERROR", colour: fgRed)

let Info*: LogLevel = LogLevel(name: "INFO", colour: fgMagenta)

let Debug*: LogLevel = LogLevel(name: "DEBUG", colour: fgGreen)
