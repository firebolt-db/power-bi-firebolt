// Use this file to write queries to test your data connector
let
    result = Firebolt.Contents("{{ACCOUNT}}", "{{ENGINE}}", "{{DATABASE}}")
in
    result
