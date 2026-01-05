%{
#include <stdio.h>
#include "limbaj.tab.h"
#include <string>
#include "SymTable.h"
extern SymTable* globalScope;
%}
%option noyywrap
%%
"int"|"float"|"string"|"bool" {yylval.Str = new std::string(yytext); return TYPE;}
"class" {return CLASS;}
"if" {return IF;}
"else" {return ELSE;}
"while" {return WHILE;}
"return" {return RETURN;}
"Print" {return PRINT;}
"true"|"false" {yylval.Str = new std::string(yytext); return BOOL_VAL;}
"begin_progr" {return BGIN;}
"end_progr" {return END;}
[a-zA-Z_][a-zA-Z0-9_]* {yylval.Str = new std::string(yytext); 
                    if (globalScope && globalScope->isType(yytext))//tip de date definit de utilizator
                        return TYPE_NAME;
                    return ID;}
"=" {return ASSIGN;}
"==" {return EQ;}
"!=" {return NEQ;}
"<=" {return LEQ;}
">=" {return GEQ;}
"<" {return LT;}
">" {return GT;}
"&&" {return AND;}
"||" {return OR;}
"!" {return NOT;}
[0-9]+ {yylval.Str = new std::string(yytext); return INT_VAL;}
[0-9]+"."[0-9]+ {yylval.Str = new std::string(yytext); return FLOAT_VAL;}
\"[^\"]*\" {yylval.Str = new std::string(yytext); return STRING_VAL;}
[ \t] ;
\n {yylineno++;}
. {return yytext[0];}
%%