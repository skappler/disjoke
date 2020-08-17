
# Package

version       = "3.0.0"
author        = "Jake Leahy"
description   = "The one and only wow such joke discord bot, now in nim"
license       = "MIT"
srcDir        = "src"
bin           = @["disjoke"]



# Dependencies

requires "nim >= 1.2.0"
requires "allographer >= 0.12.4"
requires "dimscord#head"
requires "packedjson"
requires "https://github.com/ire4ever1190/soundex-nim"

task release, "Build release binary":
    echo("Building binary")
    exec("nim c -d:release -d:danger --opt:speed src/disjoke.nim")
    echo("Stripping binary")
    exec(findExe("strip") & " -s build/disjoke")
    echo("Running upx")
    exec("upx --best build/disjoke")

task deploy, "Build and then run deploy script (personal use)":
    echo("Building")
    exec("nimble release")
    echo("Running deploy")
    exec("./deploy.sh")
