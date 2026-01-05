This project implements a compiler for a custom-designed programming language using C++ and YACC/BISON. The compiler supports variable and class declarations, arithmetic and boolean expressions, control statements, functions, symbol tables, semantic analysis, and evaluation of expressions using abstract syntax trees (AST).

Features

Data Types & Classes: int, float, string, bool; class declarations, object initialization, field/method access.

Expressions & Statements: Arithmetic and boolean expressions, assignments, if/while, function calls, Print(expr).

Symbol Tables: Global, class, and function scopes; tracks variables, functions, types, and values; printed to tables.txt.

Semantic Analysis: Detects undefined/redeclared identifiers, type errors, and parameter mismatches; validates class fields/methods.

AST Evaluation: Builds ASTs for assignments and Print statements; evaluates expressions and updates symbol tables.
