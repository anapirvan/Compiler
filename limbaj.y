%code requires {
  #include <string>
  #include <memory>
  #include <vector>
  #include "AST.h"
  extern std::string fun_name;
  using namespace std;
}

%{
#include <iostream>
#include <fstream>
#include "SymTable.h"
extern FILE* yyin;
extern char* yytext;
extern int yylineno;
extern int yylex();
void yyerror(const char * s);
class SymTable* globalScope;
class SymTable* currentScope;
std::string fun_name;
int errorCount = 0;
int error=0;
%}

%union {
     std::string* Str;
     std::vector<std::string>* StrVec;
     std::shared_ptr<ASTNode>* astNode;
}

%token BGIN END ASSIGN CLASS IF ELSE WHILE RETURN PRINT
%token EQ NEQ LEQ GEQ LT GT AND OR NOT

/* Tokens with semantic values */
%token<Str> ID TYPE INT_VAL FLOAT_VAL BOOL_VAL STRING_VAL TYPE_NAME

/* Non-terminal types */
%type<Str> any_type 

%type<StrVec> arg_list 

%type<astNode> expr func_call
%type<astNode> statement assignment print_statement if_statement while_statement return_statement

%left OR
%left AND
%left EQ NEQ
%left LT GT LEQ GEQ
%left '+' '-'
%left '*' '/' '%'
%right NOT
%right UMINUS

%start progr
%%

progr : global_declarations main { 
          if (errorCount == 0) 
              cout << "The program is correct!" << endl;
      }
      ;

global_declarations : /* empty */
                    | global_declarations global_decl
                    ;

global_decl : var_decl
            | func_decl
            | class_decl
            ;

/* Variable declarations */
var_decl : any_type ID ';' { 
            if(!currentScope->existsId(*$2)) {
                currentScope->addVar(*$1,*$2);
   
            } else {
                errorCount++; 
                std::string errMsg = "Variable '" + *$2 + "' already declared in this scope";
                yyerror(errMsg.c_str());
                error=1;
            }
            delete $1;
            delete $2;
         }
         ;

any_type : TYPE { $$ = $1; }
         | TYPE_NAME { $$ = $1; } 
         ;

/* Function declarations */
func_decl : any_type ID '('
    {
        if(currentScope->existsId(*$2)) {
            errorCount++;
            std::string errMsg = "Function '" + *$2 + "' already declared in this scope";
            yyerror(errMsg.c_str());
            error=1;
        }
        else{
            SymTable* funcScope = new SymTable(*$2, currentScope);
            currentScope = funcScope;
            currentScope->parent->addFun(*$1, *$2);
            fun_name=*$2;
        }
            delete $1;
            delete $2;
        
    }
     param_list ')' '{' func_body '}'
    {
        if(error==0)
        {
            currentScope->printVars();
            currentScope = currentScope->parent;
        }
        else error=0;
    }
    | any_type ID '(' ')' '{'
    {
        // Verifică dacă funcția există deja în scope-ul curent
        if(currentScope->existsId(*$2)) {
            errorCount++;
            std::string errMsg = "Function '" + *$2 + "' already declared in this scope";
            yyerror(errMsg.c_str());
            error=1;
        }
        else{
        SymTable* funcScope = new SymTable(*$2, currentScope);
        currentScope = funcScope;

        currentScope->parent->addFun(*$1, *$2);
        }

        delete $1;
        delete $2;
    }
    func_body '}'
    {
        if(error==0)
        {
        currentScope->printVars();
        currentScope = currentScope->parent;
        }
        else error=0;
    }
    ;



param_list : param
           | param_list ',' param
           ;
            
param : any_type ID {
            if(error==0){
                if(!currentScope->existsId(*$2)) {
                    currentScope->addVar(*$1,*$2);
                    currentScope->parent->addParamFun(fun_name,*$1,*$2);
                } else {
                    errorCount++; 
                    std::string errMsg = "Parameter '" + *$2 + "' already declared";
                    yyerror(errMsg.c_str());
                }
            }
            
          delete $1;
          delete $2;
      }
      ;

func_body : local_declarations statement_list
          ;

local_declarations : /* empty */
                   | local_declarations var_decl
                   ;

/* Class declarations */
class_decl : CLASS ID '{'
    {
        // Verifică dacă clasa există deja
        if(currentScope->isType(*$2)) {
            errorCount++;
            std::string errMsg = "Class '" + *$2 + "' already declared in this scope";
            yyerror(errMsg.c_str());
        }

        SymTable* classScope = new SymTable(*$2, currentScope);
        currentScope = classScope;

        currentScope->parent->addType(*$2);

        delete $2;
    }
    class_body '}' ';'
    {
        currentScope->printVars();
        currentScope = currentScope->parent;
    }
    ;


class_body : /* empty */
           | class_body class_member
           ;

class_member : var_decl
             | method_decl
             ;

method_decl : any_type ID '('
    {
        if(currentScope->existsId(*$2)) {
            errorCount++;
            std::string errMsg = "Function '" + *$2 + "' already declared in this scope";
            yyerror(errMsg.c_str());
            error=1;
        }
        else{
            SymTable* funcScope = new SymTable(*$2, currentScope);
            currentScope = funcScope;
            currentScope->parent->addFun(*$1, *$2);
            fun_name=*$2;
        }
        
        delete $1;
        delete $2;
    }
     param_list ')' '{' func_body '}'
    {
        if(error==0)
        {
            currentScope->printVars();
            currentScope = currentScope->parent;
        }
        else error=0;
    }
    | any_type ID '(' ')' '{'
    {
        if(currentScope->existsId(*$2)) {
            errorCount++;
            std::string errMsg = "Function '" + *$2 + "' already declared in this scope";
            yyerror(errMsg.c_str());
            error=1;
        }
        else{
            SymTable* methodScope = new SymTable(*$2, currentScope);
            currentScope = methodScope;

            currentScope->parent->addFun(*$1, *$2);
        }
        
        delete $1;
        delete $2;
    }
    func_body '}'
    {
        if(error==0)
        {
        currentScope->printVars();
        currentScope = currentScope->parent;
        }
        else error=0;
    }
;


/* Main block */
main : BGIN statement_list END
     ;

statement_list
    : /* empty */
    | statement_list statement ';'{
        // Evaluează AST-ul instrucțiunii (dacă nu e NULL)
        if ($2 && *$2) {
            (*$2)->evaluate();
        }
        if ($2) {
            delete $2;
        }
    }
    ;

statement
    : assignment{$$=$1;}
    | func_call{$$=$1;}
    | if_statement{$$=nullptr;}
    | while_statement{$$=nullptr;}
    | return_statement{$$=nullptr;}
    | print_statement{$$=$1;}
    ;

assignment : ID ASSIGN expr {

            // Verifică dacă variabila a fost declarată
               if (!currentScope->isDeclared(*$1)) {
                   errorCount++;
                   std::string errMsg = "Variable '" + *$1 + "' not declared";
                   yyerror(errMsg.c_str());
                   $$=nullptr;
                } 
                else {
                // Verifică compatibilitatea tipurilor
                std::string varType = currentScope->getVarType(*$1);
                std::string exprType = (*$3)->exprType;
                
                if (varType != exprType && exprType != "error") {
                    errorCount++;
                    string errMsg = "Type mismatch in assignment: cannot assign '" + exprType + "' to '" + varType + "'";
                    yyerror(errMsg.c_str());
                    $$=nullptr;
                }
                else
                {
                    // Creează AST pentru atribuire
                    $$ = new shared_ptr<ASTNode>(new ASTNode(*$1, *$3, currentScope));
                }
            }
            delete $1;
            delete $3;
           }
           | ID '.' ID ASSIGN expr {
               // Verificare: obj.field = expr
               std::string objName = *$1;
               std::string fieldName = *$3;
               
               // 1. Verifică dacă variabila obj există
               if (!currentScope->isDeclared(objName)) {
                   errorCount++;
                   std::string errMsg = "Variable '" + objName + "' not declared";
                   yyerror(errMsg.c_str());
               } 
               else {
                   // 2. Găsește tipul variabilei obj
                   string objType = currentScope->getVarType(objName);
                   
                   // 3. Găsește scope-ul clasei (tipul obiectului)
                   SymTable* classScope = globalScope->findClassScope(objType);
                   
                   if (classScope == nullptr) {
                       errorCount++;
                       std::string errMsg = "Type '" + objType + "' not found";
                       yyerror(errMsg.c_str());
                    }
                    else 
                    {
                       // 4. Verifică dacă field-ul există în clasă
                       if (!classScope->existsId(fieldName)) {
                           errorCount++;
                           std::string errMsg = "Field '" + fieldName + "' does not exist in class '" + objType + "'";
                           yyerror(errMsg.c_str());
                       } 
                       else {
                           // 5. Verifică compatibilitatea tipurilor
                           string fieldType = classScope->getVarType(fieldName);
                           string exprType = (*$5)->exprType;
                           
                           if (fieldType != exprType && exprType != "error") {
                               errorCount++;
                               std::string errMsg = "Type mismatch in assignment to field: cannot assign '" + exprType + "' to '" + fieldType + "'";
                               yyerror(errMsg.c_str());
                           }
                       }
                   }
               }
               $$ = nullptr; // Nu construim AST pentru membri de clasă (cerință)
               delete $1;
               delete $3;
               delete $5;
           }
           ;


func_call : ID '(' arg_list ')' {
              // Verifică dacă funcția a fost declarată
              if (!currentScope->isDeclared(*$1)) {
                  errorCount++;
                  std::string errMsg = "Function '" + *$1 + "' not declared";
                  yyerror(errMsg.c_str());
                  $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
              } 
              else 
              {
                   // Verify parameter types
                  vector<string> expectedParams = currentScope->getFunParams(*$1);
                  if (expectedParams.size() != $3->size()) {
                      errorCount++;
                      std::string errMsg = "Function '" + *$1 + "' expects " + 
                                          std::to_string(expectedParams.size()) + 
                                          " parameters, but " + std::to_string($3->size()) + 
                                          " were provided";
                      yyerror(errMsg.c_str());
                      $$ = new std::shared_ptr<ASTNode>(
                        new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                  } 
                  else 
                  {
                      // Check each parameter type
                      for (int i = 0; i < expectedParams.size(); i++) {
                          if (expectedParams[i] != (*$3)[i] && (*$3)[i] != "error") {
                              errorCount++;
                              std::string errMsg = "Parameter " + std::to_string(i+1) + 
                                                  " type mismatch: expected '" + expectedParams[i] + 
                                                  "' but got '" + (*$3)[i] + "'";
                              yyerror(errMsg.c_str());
                              $$ = new std::shared_ptr<ASTNode>(
                                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                          }
                      }
                  }
                  std::string funType = currentScope->getFunType(*$1);
                  $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", funType, currentScope));
              }
                delete $1;
                delete $3;
              }

          | ID '(' ')' {
             // Verifică dacă funcția a fost declarată
              if (!currentScope->isDeclared(*$1)) {
                  errorCount++;
                  std::string errMsg = "Function '" + *$1 + "' not declared";
                  yyerror(errMsg.c_str());
                  $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
              } else {
                  // Verify no parameters expected
                  std::vector<std::string> expectedParams = currentScope->getFunParams(*$1);
                  if (expectedParams.size() != 0) {
                      errorCount++;
                      std::string errMsg = "Function '" + *$1 + "' expects " + 
                                          std::to_string(expectedParams.size()) + 
                                          " parameters, but 0 were provided";
                      yyerror(errMsg.c_str());
                      $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                  }
                  // Returnează tipul funcției
                  std::string funType = currentScope->getFunType(*$1);
                  $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", funType, currentScope));
              }
              delete $1;
          }
          | ID '.' ID '(' arg_list ')' {
            // Verificare: obj.method(...)
              std::string objName = *$1;
              std::string methodName = *$3;
              
              // 1. Verifică dacă variabila obj există
              if (!currentScope->isDeclared(objName)) {
                  errorCount++;
                  std::string errMsg = "Variable '" + objName + "' not declared";
                  yyerror(errMsg.c_str());
                  $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
              } 
              else {
                  // 2. Găsește tipul obiectului
                  std::string objType = currentScope->getVarType(objName);
                  
                  // 3. Găsește clasa
                  SymTable* classScope = globalScope->findClassScope(objType);
                  
                  if (classScope == nullptr) {
                      errorCount++;
                      std::string errMsg = "Type '" + objType + "' not found";
                      yyerror(errMsg.c_str());
                      $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                  } 
                  else 
                  {
                      // 4. Verifică dacă metoda există
                      if (!classScope->existsId(methodName)) {
                          errorCount++;
                          std::string errMsg = "Method '" + methodName + "' does not exist in class '" + objType + "'";
                          yyerror(errMsg.c_str());
                          $$ = new std::shared_ptr<ASTNode>(
                            new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                      } else {
                          // Verify parameter types for method
                          std::vector<std::string> expectedParams = classScope->getFunParams(methodName);
                          if (expectedParams.size() != $5->size()) {
                              errorCount++;
                              std::string errMsg = "Method '" + methodName + "' expects " + 
                                                  std::to_string(expectedParams.size()) + 
                                                  " parameters, but " + std::to_string($5->size()) + 
                                                  " were provided";
                              yyerror(errMsg.c_str());
                              $$ = new std::shared_ptr<ASTNode>(
                                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                          } else {
                              for (int i = 0; i < expectedParams.size(); i++) {
                                  if (expectedParams[i] != (*$5)[i] && (*$5)[i] != "error") {
                                      errorCount++;
                                      std::string errMsg = "Parameter " + std::to_string(i+1) + 
                                                          " type mismatch: expected '" + expectedParams[i] + 
                                                          "' but got '" + (*$5)[i] + "'";
                                      yyerror(errMsg.c_str());
                                      $$ = new std::shared_ptr<ASTNode>(
                                        new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                                  }
                              }
                          }
                          // Returnează tipul metodei
                       std::string funType = classScope->getFunType(methodName);
                       $$ = new std::shared_ptr<ASTNode>(
                        new ASTNode(ASTNode::OTHER_NODE, "", funType, currentScope));
                      }
                  }
              }
              delete $1;
              delete $3;
              delete $5;
          }
          | ID '.' ID '(' ')' {
              // Verificare: obj.method(...)
              std::string objName = *$1;
              std::string methodName = *$3;
              
              // 1. Verifică dacă variabila obj există
              if (!currentScope->isDeclared(objName)) {
                  errorCount++;
                  std::string errMsg = "Variable '" + objName + "' not declared";
                  yyerror(errMsg.c_str());
                  $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
              } 
              else {
                  // 2. Găsește tipul obiectului
                  std::string objType = currentScope->getVarType(objName);
                  
                  // 3. Găsește clasa
                  SymTable* classScope = globalScope->findClassScope(objType);
                  
                  if (classScope == nullptr) {
                      errorCount++;
                      std::string errMsg = "Type '" + objType + "' not found";
                      yyerror(errMsg.c_str());
                      $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                  } 
                  else 
                  {
                      // 4. Verifică dacă metoda există
                      if (!classScope->existsId(methodName)) {
                          errorCount++;
                          std::string errMsg = "Method '" + methodName + "' does not exist in class '" + objType + "'";
                          yyerror(errMsg.c_str());
                          $$ = new std::shared_ptr<ASTNode>(
                            new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                      }else {
                        // Verify no parameters expected for method
                          std::vector<std::string> expectedParams = classScope->getFunParams(methodName);
                          if (expectedParams.size() != 0) {
                              errorCount++;
                              std::string errMsg = "Method '" + methodName + "' expects " + 
                                                  std::to_string(expectedParams.size()) + 
                                                  " parameters, but 0 were provided";
                              yyerror(errMsg.c_str());
                              $$ = new std::shared_ptr<ASTNode>(
                                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                          }
                          // Returnează tipul metodei
                          std::string funType = classScope->getFunType(methodName);
                          $$ = new std::shared_ptr<ASTNode>(
                                new ASTNode(ASTNode::OTHER_NODE, "", funType, currentScope));
                      }
                  }
              }
              delete $1;
              delete $3;
          }
          ;

arg_list : expr{
    $$ = new vector<string>();
    $$->push_back((*$1)->exprType);
    delete $1;
}
         | arg_list ',' expr{
            $$ = $1;
            $$->push_back((*$3)->exprType);
            delete $3;
         }
         ;

if_statement : IF '(' expr ')' '{' statement_list '}' ELSE '{' statement_list '}'{
    $$=nullptr;
    delete $3;
}
             ;

while_statement : WHILE '(' expr ')' '{' statement_list '}'{
    $$=nullptr;
    delete $3;
}
                ;

return_statement : RETURN expr { 
    $$=nullptr;
    delete $2;
    }
    ;

print_statement : PRINT '(' expr ')' {
    // Creează AST pentru Print
                    $$ = new shared_ptr<ASTNode>(
                        new ASTNode(ASTNode::PRINT, *$3, (*$3)->exprType, currentScope)
                    );
                    delete $3;
                }
                ;

/* Expressions */
expr
    : '(' expr ')'        { std::cout << "DEBUG: Paranteze evaluate pentru expresie de tip: " << (*$2)->exprType << std::endl; $$ = $2; }
    |INT_VAL             { 
        $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::INT_NODE, *$1, "int", currentScope)
        );
        delete $1; 
        }
    | FLOAT_VAL           { 
        $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::FLOAT_NODE, *$1, "float", currentScope)
        );
        delete $1; 
        }
    |BOOL_VAL            { 
        $$ = new std::shared_ptr<ASTNode>(
            new ASTNode(ASTNode::BOOL_NODE, *$1, "bool", currentScope)
        );
        delete $1;
     }
    | STRING_VAL          { 
         $$ = new std::shared_ptr<ASTNode>(
            new ASTNode(ASTNode::STRING_NODE, *$1, "string", currentScope));
        delete $1; 
        }
    | ID { 
        // Verifică dacă ID a fost declarat
        if (!currentScope->isDeclared(*$1)) {
            errorCount++;
            std::string errMsg = "Variable '" + *$1 + "' not declared";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope)
            );
        }
        else {
            string varType = currentScope->getVarType(*$1);
            $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::ID_NODE, *$1, varType, currentScope)
            );
        }
        delete $1; 
        }
    | ID '.' ID           { 
        std::string objName = *$1;
        std::string fieldName = *$3;
               
        // 1. Verifică dacă variabila obj există
        if (!currentScope->isDeclared(objName)) {
            errorCount++;
            std::string errMsg = "Variable '" + objName + "' not declared";
            yyerror(errMsg.c_str());
            $$ = new std::shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        } 
        else 
        {
            // 2. Găsește tipul variabilei obj
            std::string objType = currentScope->getVarType(objName);
                   
            // 3. Găsește scope-ul clasei (tipul obiectului)
            SymTable* classScope = globalScope->findClassScope(objType);
                   
            if (classScope == nullptr) {
                errorCount++;
                std::string errMsg = "Type '" + objType + "' not found";
                yyerror(errMsg.c_str());
                $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
            }
            else 
            {
                // 4. Verifică dacă field-ul există în clasă
                if (!classScope->existsId(fieldName)) {
                    errorCount++;
                    std::string errMsg = "Field '" + fieldName + "' does not exist in class '" + objType + "'";
                    yyerror(errMsg.c_str());
                    $$ = new std::shared_ptr<ASTNode>(
                      new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
                    }
                else{
                   std::string fieldType = classScope->getVarType(fieldName);
                    $$ = new shared_ptr<ASTNode>(
                        new ASTNode(ASTNode::OTHER_NODE, "", fieldType, currentScope));
                }
            }
        }
        delete $1; 
        delete $3; 
        }
        ;

    | func_call { $$ = $1; }
    | expr '+' expr { 
        // Verifică că ambii operanzi au același tip
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error")  {
            errorCount++;
            std::string errMsg = "Type mismatch in addition: '" + (*$1)->exprType + "' + '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
            $$ = new std::shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        } 
        else if (((*$1)->exprType != "int" && (*$1)->exprType != "float") || ((*$3)->exprType != "int" && (*$3)->exprType != "float")) {
            if ((*$1)->exprType != "error" && (*$3)->exprType != "error") {
                errorCount++;
                std::string errMsg = "Invalid type for arithmetic operation";
                yyerror(errMsg.c_str());
                $$ = new std::shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
            }
            $$ = new std::shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope)
            );
        } else {
            $$ = new std::shared_ptr<ASTNode>(
            new ASTNode(ASTNode::ADD, *$1, *$3, (*$1)->exprType, currentScope)
        );
        }
        delete $1;
        delete $3;
     }
    | expr '-' expr { 
        // Verifică că ambii operanzi au același tip
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            std::string errMsg = "Type mismatch in substraction: '" + (*$1)->exprType + "' + '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
            $$ = new std::shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope)
            );
        } else if (((*$1)->exprType != "int" && (*$1)->exprType != "float") || ((*$3)->exprType != "int" && (*$3)->exprType != "float")) {
            if ((*$1)->exprType != "error" && (*$3)->exprType != "error") {
                errorCount++;
                std::string errMsg = "Invalid type for arithmetic operation";
                yyerror(errMsg.c_str());
            }
            $$ = new std::shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope)
            );
        } else {
            $$ = new std::shared_ptr<ASTNode>(
            new ASTNode(ASTNode::SUB, *$1, *$3, (*$1)->exprType, currentScope)
        );
        }
        delete $1;
        delete $3;
     }
    | expr '*' expr { 
        // Verifică că ambii operanzi au același tip
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            string errMsg = "Type mismatch in multiplication: '" + (*$1)->exprType + "' + '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
            $$ = new std::shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope)
            );
        } else if (((*$1)->exprType != "int" && (*$1)->exprType != "float") || ((*$3)->exprType != "int" && (*$3)->exprType != "float")) {
            if ((*$1)->exprType != "error" && (*$3)->exprType != "error") {
                errorCount++;
                string errMsg = "Invalid type for arithmetic operation";
                yyerror(errMsg.c_str());
            }
            $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope)
            );
        } else {
             $$ = new shared_ptr<ASTNode>(
             new ASTNode(ASTNode::MUL, *$1, *$3, (*$1)->exprType, currentScope)
        );
        }
        delete $1;
        delete $3;
     }
    | expr '/' expr { 
        // Verifică că ambii operanzi au același tip
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            string errMsg = "Type mismatch in division: '" + (*$1)->exprType + "' + '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope)
            );
        } else if (((*$1)->exprType != "int" && (*$1)->exprType != "float") || ((*$3)->exprType != "int" && (*$3)->exprType != "float")) {
            if ((*$1)->exprType != "error" && (*$3)->exprType != "error") {
                errorCount++;
                string errMsg = "Invalid type for arithmetic operation";
                yyerror(errMsg.c_str());
            }
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope)
            );
        } else {
            $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::DIV, *$1, *$3, (*$1)->exprType, currentScope)
        );
        }
        delete $1;
        delete $3;
     }
    | expr '%' expr { 
        // Verifică că ambii operanzi au același tip
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            string errMsg = "Type mismatch in modulo: '" + (*$1)->exprType + "' + '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope)
            );
        } else if (((*$1)->exprType != "int" && (*$1)->exprType != "float") || ((*$3)->exprType != "int" && (*$3)->exprType != "float")) {
            if ((*$1)->exprType != "error" && (*$3)->exprType != "error") {
                errorCount++;
                string errMsg = "Invalid type for arithmetic operation";
                yyerror(errMsg.c_str());
            }
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope)
            );
        } else {
            $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::MOD, *$1, *$3, (*$1)->exprType, currentScope)
        );
        }
        delete $1;
        delete $3;
     }
    | '-' expr %prec UMINUS    { 
        if ((*$2)->exprType != "int" && (*$2)->exprType != "float" && (*$2)->exprType != "error") {
            errorCount++;
            std::string errMsg = "Invalid type for unary minus: '" + (*$2)->exprType + "'";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        } else {
            $$ = new std::shared_ptr<ASTNode>(
            new ASTNode(ASTNode::UMINUS, *$2, (*$2)->exprType, currentScope)
        );
        }
        delete $2;
     }
    | expr EQ  expr { 
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            string errMsg = "Type mismatch in comparison: '" + (*$1)->exprType + "' == '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        }
         $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::EQ, *$1, *$3, "bool", currentScope));
        delete $1;
        delete $3;
    }
    | expr NEQ expr { 
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            string errMsg = "Type mismatch in comparison: '" + (*$1)->exprType + "' != '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        }
         $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::NEQ, *$1, *$3, "bool", currentScope));
        delete $1;
        delete $3; 
        }
    | expr LT expr { 
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            string errMsg = "Type mismatch in comparison: '" + (*$1)->exprType + "' < '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        }
        $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::LT, *$1, *$3, "bool", currentScope));
        delete $1;
        delete $3;
    }
    | expr GT expr { 
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            string errMsg = "Type mismatch in comparison: '" + (*$1)->exprType + "' > '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        }
         $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::GT, *$1, *$3, "bool", currentScope));
        delete $1;
        delete $3;
    }
    | expr LEQ expr { 
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            string errMsg = "Type mismatch in comparison: '" + (*$1)->exprType + "' <= '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        }
        $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::LEQ, *$1, *$3, "bool", currentScope));
        delete $1;
        delete $3; 
        }
    | expr GEQ expr { 
        if ((*$1)->exprType != (*$3)->exprType && (*$1)->exprType != "error" && (*$3)->exprType != "error"){
            errorCount++;
            string errMsg = "Type mismatch in comparison: '" + (*$1)->exprType + "' >= '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        }
       $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::GEQ, *$1, *$3, "bool", currentScope));
        delete $1;
        delete $3;
    }
    | expr AND expr       { 
        if (((*$1)->exprType != "bool" || (*$3)->exprType != "bool") && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            string errMsg = "Logical AND requires bool operands, got '" + (*$1)->exprType + "' and '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
             $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        }
        $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::AND, *$1, *$3, "bool", currentScope));
        delete $1;
        delete $3;
    }
    | expr OR expr       { 
        if (((*$1)->exprType != "bool" || (*$3)->exprType != "bool") && (*$1)->exprType != "error" && (*$3)->exprType != "error") {
            errorCount++;
            string errMsg = "Logical OR requires bool operands, got '" + (*$1)->exprType + "' and '" + (*$3)->exprType + "'";
            yyerror(errMsg.c_str());
            $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        }
        $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::OR, *$1, *$3, "bool", currentScope));
        delete $1;
        delete $3;
    }
    | NOT expr                    { 
        if ((*$2)->exprType != "bool" && (*$2)->exprType != "error") {
            errorCount++;
            std::string errMsg = "NOT operator requires bool operand, got '" + (*$2)->exprType + "'";
            yyerror(errMsg.c_str());
            $$ = new shared_ptr<ASTNode>(
                new ASTNode(ASTNode::OTHER_NODE, "", "error", currentScope));
        }
         $$ = new shared_ptr<ASTNode>(
            new ASTNode(ASTNode::NOT, *$2, "bool", currentScope));
        delete $2;
    }
    ;


%%

void yyerror(const char * s){
     cout << "error: " << s << " at line: " << yylineno << endl;
}

int main(int argc, char** argv){
     yyin=fopen(argv[1],"r");
     FILE* f=fopen("tables.txt", "w");
     fclose(f);
     globalScope = new SymTable("global");
     currentScope=globalScope;
     yyparse();
     globalScope->printVars();
     delete globalScope;
     return 0;
}