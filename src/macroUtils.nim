import macros

proc newParam*(name, value: string): NimNode =
    ## Creates a node for a parameter
    return nnkExprEqExpr.newTree(
        newIdentNode(name),
        newlit(value)
    )

proc dot*(left, right: string): NimNode =
    return nnkDotExpr.newTree(
        newIdentNode(left),
        newIdentNode(right)
    )
