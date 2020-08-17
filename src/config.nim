import macros
import json

macro createConfigValues(): untyped =
    result = nnkConstSection.newTree()
    let configJson = parseJson(readFile("config.json"))
    for (key, value) in configJson.pairs():
        echo(key,": ", value.getStr())
        result.add(
            nnkConstDef.newTree(
                nnkPostFix.newTree(
                    newIdentNode("*"),
                    newIdentNode(key)
                ),
                newEmptyNode(),
                newLit(value.getStr())
            )
        )
createConfigValues()
