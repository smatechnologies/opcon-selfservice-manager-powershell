function OpConsole_CheckExpression()
{
    $ExpressionDialog = [Terminal.Gui.Dialog]::new()
    $ExpressionDialog.Title = "Check Expressions, [Escape] to close"

    #Expression
    $ExpressionLabel = [Terminal.Gui.Label]::new()
    $ExpressionLabel.Height = 1
    $ExpressionLabel.Width = 15
    $ExpressionLabel.Text = "Expression"

    $ExpressionTextfield = [Terminal.Gui.Textfield]::new()
    $ExpressionTextfield.Width = 250
    $ExpressionTextfield.X = [Terminal.Gui.Pos]::Right($ExpressionLabel)

    $ExpressionDialog.Add($ExpressionLabel) 
    $ExpressionDialog.Add($ExpressionTextfield)

    # Submit button
    $ExpressionSubmit = [Terminal.Gui.Button]::new()
    $ExpressionSubmit.Text = "Check Expression"
    $ExpressionSubmit.add_Clicked({ 
        $validation = OpCon_PropertyExpression -url $global:activeOpCon.url -token $global:activeOpCon.externalToken -expression $ExpressionTextfield.text.ToString()

        if($validation.result -eq "true")
        { [Terminal.Gui.MessageBox]::Query("Result", "The expression was true!","OK") }
        else 
        { [Terminal.Gui.MessageBox]::Query("Result", "The expression was false!","OK") }
    })
    $ExpressionSubmit.Y = [Terminal.Gui.Pos]::Bottom($ExpressionTextfield)
    $ExpressionSubmit.X = [Terminal.Gui.Pos]::Center()
    $ExpressionDialog.Add($ExpressionSubmit)

    [Terminal.Gui.Application]::Run($ExpressionDialog)
}