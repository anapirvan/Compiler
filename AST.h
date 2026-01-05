#ifndef AST_H
#define AST_H

#include <string>
#include <iostream>
#include <memory>
#include "SymTable.h"

using namespace std;

// Wrapper class pentru toate valorile din limbaj
class Value
{
public:
    enum Type
    {
        INT,
        FLOAT,
        BOOL,
        STRING,
        NONE
    };

    Type type;
    int intVal;
    float floatVal;
    bool boolVal;
    string stringVal;

    Value() : type(NONE), intVal(0), floatVal(0.0f), boolVal(false), stringVal("") {}

    Value(int v) : type(INT), intVal(v), floatVal(0.0f), boolVal(false), stringVal("") {}
    Value(float v) : type(FLOAT), intVal(0), floatVal(v), boolVal(false), stringVal("") {}
    Value(bool v) : type(BOOL), intVal(0), floatVal(0.0f), boolVal(v), stringVal("") {}
    Value(const string &v) : type(STRING), intVal(0), floatVal(0.0f), boolVal(false), stringVal(v) {}

    // Returnează valoarea implicită pentru un tip
    static Value defaultForType(const std::string &typeName)
    {
        if (typeName == "int")
            return Value(0);
        if (typeName == "float")
            return Value(0.0f);
        if (typeName == "bool")
            return Value(false);
        if (typeName == "string")
            return Value("");
        return Value();
    }

    void print() const
    {
        switch (type)
        {
        case INT:
            cout << intVal;
            break;
        case FLOAT:
            cout << floatVal;
            break;
        case BOOL:
            cout << (boolVal ? "true" : "false");
            break;
        case STRING:
            cout << stringVal;
            break;
        case NONE:
            cout << "none";
            break;
        }
    }
};

class ASTNode
{
public:
    enum NodeType
    {
        // Operanzi
        INT_NODE,
        FLOAT_NODE,
        BOOL_NODE,
        STRING_NODE,
        ID_NODE,
        OTHER_NODE,
        // Operatori binari aritmetici
        ADD,
        SUB,
        MUL,
        DIV,
        MOD,
        // Operatori binari de comparație
        EQ,
        NEQ,
        LT,
        GT,
        LEQ,
        GEQ,
        // Operatori binari logici
        AND,
        OR,
        // Operatori unari
        NOT,
        UMINUS,
        // Instrucțiuni
        ASSIGN,
        PRINT
    };

    NodeType nodeType;
    string value;    // Pentru ID_NODE, sau valori literale
    string exprType; // Tipul expresiei (int, float, bool, string)
    string varName;

    shared_ptr<ASTNode> left;
    shared_ptr<ASTNode> right;

    SymTable *scope; // Scope-ul în care se evaluează AST-ul

    // Constructor pentru noduri fără copii (operanzi)
    ASTNode(NodeType type, const string &val, const string &exprTyp, SymTable *sc)
        : nodeType(type), value(val), exprType(exprTyp), varName(""), left(nullptr), right(nullptr), scope(sc) {}

    // Constructor pentru operatori binari
    ASTNode(NodeType type, shared_ptr<ASTNode> l, shared_ptr<ASTNode> r, const string &exprTyp, SymTable *sc)
        : nodeType(type), value(""), exprType(exprTyp), varName(""), left(l), right(r), scope(sc) {}

    // Constructor pentru operatori unari
    ASTNode(NodeType type, shared_ptr<ASTNode> l, const string &exprTyp, SymTable *sc)
        : nodeType(type), value(""), exprType(exprTyp), varName(""), left(l), right(nullptr), scope(sc) {}

    // Constructor pentru ASSIGN
    ASTNode(const string &var, shared_ptr<ASTNode> expr, SymTable *sc)
        : nodeType(ASSIGN), value(""), exprType(expr->exprType), varName(var), left(nullptr), right(expr), scope(sc) {}

    // Evaluează AST-ul și returnează rezultatul
    Value evaluate()
    {
        // Noduri fără copii (frunze)
        if (!left && !right)
        {
            switch (nodeType)
            {
            case INT_NODE:
                return Value(stoi(value));

            case FLOAT_NODE:
                return Value(stof(value));

            case BOOL_NODE:
                return Value(value == "true");

            case STRING_NODE:
                // Elimină ghilimelele din string
                return Value(value.substr(1, value.length() - 2));

            case ID_NODE:
            {
                // Caută valoarea variabilei în SymTable
                if (scope && scope->isDeclared(value))
                {
                    auto it = scope->symbols.find(value);
                    if (it != scope->symbols.end())
                    {
                        // Convertește string-ul stocat în Value
                        const string &storedValue = it->second.value;
                        const string &type = it->second.type;

                        if (storedValue.empty())
                        {
                            return Value::defaultForType(type);
                        }

                        if (type == "int")
                            return Value(stoi(storedValue));
                        if (type == "float")
                            return Value(stof(storedValue));
                        if (type == "bool")
                            return Value(storedValue == "true");
                        if (type == "string")
                            return Value(storedValue);
                    }

                    // Caută în scope-ul părinte
                    if (scope->parent)
                    {
                        SymTable *parentScope = scope->parent;
                        while (parentScope)
                        {
                            auto it = parentScope->symbols.find(value);
                            if (it != parentScope->symbols.end())
                            {
                                const std::string &storedValue = it->second.value;
                                const std::string &type = it->second.type;

                                if (storedValue.empty())
                                {
                                    return Value::defaultForType(type);
                                }

                                if (type == "int")
                                    return Value(std::stoi(storedValue));
                                if (type == "float")
                                    return Value(std::stof(storedValue));
                                if (type == "bool")
                                    return Value(storedValue == "true");
                                if (type == "string")
                                    return Value(storedValue);
                            }
                            parentScope = parentScope->parent;
                        }
                    }
                }
                return Value::defaultForType(exprType);
            }

            case OTHER_NODE:
                // Returnează valoarea implicită pentru tipul expresiei
                return Value::defaultForType(exprType);

            default:
                return Value();
            }
        }

        if (nodeType == ASSIGN)
        {
            Value result = right->evaluate();

            SymTable *s = scope;
            while (s)
            {
                auto it = s->symbols.find(varName);
                if (it != s->symbols.end())
                {
                    switch (result.type)
                    {
                    case Value::INT:
                        it->second.value = std::to_string(result.intVal);
                        break;
                    case Value::FLOAT:
                        it->second.value = std::to_string(result.floatVal);
                        break;
                    case Value::BOOL:
                        it->second.value = result.boolVal ? "true" : "false";
                        break;
                    case Value::STRING:
                        it->second.value = result.stringVal;
                        break;
                    default:
                        break;
                    }
                    return result; // ❗ important
                }
                s = s->parent;
            }

            return result;
        }

        if (nodeType == PRINT)
        {
            // Evaluează expresia
            Value result = left->evaluate();

            // Printează valoarea
            cout << "Print: ";
            result.print();
            cout << endl;

            return result;
        }

        // Operatori unari
        if (!right && left)
        {
            Value leftVal = left->evaluate();

            switch (nodeType)
            {
            case UMINUS:
                if (leftVal.type == Value::INT)
                    return Value(-leftVal.intVal);
                if (leftVal.type == Value::FLOAT)
                    return Value(-leftVal.floatVal);
                break;

            case NOT:
                if (leftVal.type == Value::BOOL)
                    return Value(!leftVal.boolVal);
                break;

            default:
                break;
            }
        }

        // Operatori binari
        if (left && right)
        {
            Value leftVal = left->evaluate();
            Value rightVal = right->evaluate();

            switch (nodeType)
            {
            // Aritmetici
            case ADD:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(leftVal.intVal + rightVal.intVal);
                if (leftVal.type == Value::FLOAT && rightVal.type == Value::FLOAT)
                    return Value(leftVal.floatVal + rightVal.floatVal);
                break;

            case SUB:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(leftVal.intVal - rightVal.intVal);
                if (leftVal.type == Value::FLOAT && rightVal.type == Value::FLOAT)
                    return Value(leftVal.floatVal - rightVal.floatVal);
                break;

            case MUL:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(leftVal.intVal * rightVal.intVal);
                if (leftVal.type == Value::FLOAT && rightVal.type == Value::FLOAT)
                    return Value(leftVal.floatVal * rightVal.floatVal);
                break;

            case DIV:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(rightVal.intVal != 0 ? leftVal.intVal / rightVal.intVal : 0);
                if (leftVal.type == Value::FLOAT && rightVal.type == Value::FLOAT)
                    return Value(rightVal.floatVal != 0.0f ? leftVal.floatVal / rightVal.floatVal : 0.0f);
                break;

            case MOD:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(rightVal.intVal != 0 ? leftVal.intVal % rightVal.intVal : 0);
                break;

            // Comparații
            case EQ:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(leftVal.intVal == rightVal.intVal);
                if (leftVal.type == Value::FLOAT && rightVal.type == Value::FLOAT)
                    return Value(leftVal.floatVal == rightVal.floatVal);
                if (leftVal.type == Value::BOOL && rightVal.type == Value::BOOL)
                    return Value(leftVal.boolVal == rightVal.boolVal);
                break;

            case NEQ:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(leftVal.intVal != rightVal.intVal);
                if (leftVal.type == Value::FLOAT && rightVal.type == Value::FLOAT)
                    return Value(leftVal.floatVal != rightVal.floatVal);
                break;

            case LT:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(leftVal.intVal < rightVal.intVal);
                if (leftVal.type == Value::FLOAT && rightVal.type == Value::FLOAT)
                    return Value(leftVal.floatVal < rightVal.floatVal);
                break;

            case GT:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(leftVal.intVal > rightVal.intVal);
                if (leftVal.type == Value::FLOAT && rightVal.type == Value::FLOAT)
                    return Value(leftVal.floatVal > rightVal.floatVal);
                break;

            case LEQ:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(leftVal.intVal <= rightVal.intVal);
                if (leftVal.type == Value::FLOAT && rightVal.type == Value::FLOAT)
                    return Value(leftVal.floatVal <= rightVal.floatVal);
                break;

            case GEQ:
                if (leftVal.type == Value::INT && rightVal.type == Value::INT)
                    return Value(leftVal.intVal >= rightVal.intVal);
                if (leftVal.type == Value::FLOAT && rightVal.type == Value::FLOAT)
                    return Value(leftVal.floatVal >= rightVal.floatVal);
                break;

                // Logici
            case AND:
                if (leftVal.type == Value::BOOL && rightVal.type == Value::BOOL)
                    return Value(leftVal.boolVal && rightVal.boolVal);
                break;

            case OR:
                if (leftVal.type == Value::BOOL && rightVal.type == Value::BOOL)
                    return Value(leftVal.boolVal || rightVal.boolVal);
                break;

            default:
                break;
            }
        }

        return Value();
    }

    // Printează AST-ul (pentru debug)
    void printAST(int indent = 0) const
    {
        string indentStr(indent * 2, ' ');

        cout << indentStr;
        switch (nodeType)
        {
        case INT_NODE:
            cout << "INT: " << value;
            break;
        case FLOAT_NODE:
            cout << "FLOAT: " << value;
            break;
        case BOOL_NODE:
            cout << "BOOL: " << value;
            break;
        case STRING_NODE:
            cout << "STRING: " << value;
            break;
        case ID_NODE:
            cout << "ID: " << value;
            break;
        case OTHER_NODE:
            cout << "OTHER";
            break;
        case ADD:
            cout << "+";
            break;
        case SUB:
            cout << "-";
            break;
        case MUL:
            cout << "*";
            break;
        case DIV:
            cout << "/";
            break;
        case EQ:
            cout << "==";
            break;
        case NEQ:
            cout << "!=";
            break;
        case LT:
            cout << "<";
            break;
        case GT:
            cout << ">";
            break;
        case LEQ:
            cout << "<=";
            break;
        case GEQ:
            cout << ">=";
            break;
        case AND:
            cout << "&&";
            break;
        case OR:
            cout << "||";
            break;
        case NOT:
            cout << "!";
            break;
        case UMINUS:
            cout << "-(unary)";
            break;
        case ASSIGN:
            cout << "ASSIGN: " << varName;
            break;
        case PRINT:
            cout << "PRINT";
            break;
        }
        cout << " [type: " << exprType << "]" << endl;

        if (left)
        {
            cout << indentStr << "Left:" << endl;
            left->printAST(indent + 1);
        }
        if (right)
        {
            cout << indentStr << "Right:" << endl;
            right->printAST(indent + 1);
        }
    }
};

#endif