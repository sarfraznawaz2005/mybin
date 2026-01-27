$diff = @"
+def new_test_function():
+    return "hello"
-class OldClass:
"@

agent "Write commit for this: $diff"
