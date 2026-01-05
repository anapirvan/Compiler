#ifndef SYMTABLE_H
#define SYMTABLE_H

#include <iostream>
#include <map>
#include <vector>
#include <string>
#include <fstream>
#include <set>

class Symbol
{
public:
    std::string name;
    std::string type;
    std::string value;

    Symbol(std::string n, std::string t, std::string v = "")
        : name(n), type(t), value(v) {}
};

class Param
{
public:
    std::string name;
    std::string type;

    Param(std::string n, std::string t)
        : name(t), type(n) {}
};

class Function
{
public:
    std::string name;
    std::string type;
    std::vector<Param> params;

    Function(std::string n, std::string t)
        : name(n), type(t) {}
    void addParam(std::string var_type, std::string var_id)
    {
        params.emplace_back(var_type, var_id);
    }
};

class SymTable
{
public:
    std::string name;
    SymTable *parent;
    std::map<std::string, Symbol> symbols; // Store identifiers
    std::map<std::string, Function> functions;
    std::ofstream outputFile; // File to write symbols
    std::vector<SymTable *> children;
    std::set<std::string> types;

    SymTable(std::string n, SymTable *p = nullptr) : name(n), parent(p)
    {
        if (parent)
            parent->children.push_back(this);
    }

    ~SymTable()
    {
        for (SymTable *child : children)
            delete child;
        outputFile.close();
    }

    void addVar(std::string type, std::string id, std::string value = "")
    {
        symbols.emplace(id, Symbol(id, type, value));
    }

    void addFun(std::string type, std::string id)
    {
        functions.emplace(id, Function(id, type));
    }

    void addParamFun(std::string id, std::string var_type, std::string var_id)
    {
        auto it = functions.find(id);
        if (it != functions.end())
        {
            it->second.addParam(var_type, var_id);
        }
    }

    bool existsId(std::string id)
    {
        return (symbols.find(id) != symbols.end() || functions.find(id) != functions.end());
    }

    void printVars()
    {
        outputFile.open("tables.txt", std::ios::app);
        outputFile << "Symbol Table: " << name << std::endl;
        for (const auto &pair : symbols)
        {
            outputFile << "ID: " << pair.second.name << ", Type: " << pair.second.type
                       << ", Value: " << pair.second.value << std::endl;
        }

        for (const auto &pair : functions)
        {
            outputFile << "ID: " << pair.second.name << ", Type: " << pair.second.type
                       << ", Params: ";
            for (const auto &par : pair.second.params)
            {
                outputFile << "ID " << par.name << ", Type " << par.type << ";";
            }
            outputFile << std::endl;
        }
    }

    void addType(const std::string &name)
    {
        types.insert(name);
    }

    bool isType(const std::string &name)
    {
        if (types.find(name) != types.end())
            return true;
        return false;
    }

    std::string getVarType(const std::string &varName)
    {
        // Caută în scope-ul curent
        auto it = symbols.find(varName);
        if (it != symbols.end())
        {
            return it->second.type;
        }

        // Caută în scope-ul părinte
        if (parent != nullptr)
        {
            return parent->getVarType(varName);
        }

        return ""; // Nu a fost găsită variabila
    }


    SymTable *findClassScope(const std::string &className)
    {
        // Caută în copiii acestui scope
        for (SymTable *child : children)
        {
            if (child->name == className)
            {
                return child;
            }
        }

        // Caută în scope-ul părinte
        if (parent != nullptr)
        {
            return parent->findClassScope(className);
        }

        return nullptr; // Clasa nu a fost găsită
    }

    bool isDeclared(const std::string &id)
    {
        // Caută în scope-ul curent
        if (existsId(id))
        {
            return true;
        }

        // Caută în scope-ul părinte
        if (parent != nullptr)
        {
            return parent->isDeclared(id);
        }

        return false;
    }

    std::string getFunType(const std::string &funName)
    {
        // Caută în scope-ul curent
        auto it = functions.find(funName);
        if (it != functions.end())
        {
            return it->second.type;
        }

        // Caută în scope-ul părinte
        if (parent != nullptr)
        {
            return parent->getFunType(funName);
        }

        return ""; // Nu a fost găsită funcția
    }


    std::vector<std::string> getFunParams(const std::string &funName)
    {
        // Search in current scope
        auto it = functions.find(funName);
        if (it != functions.end())
        {
            std::vector<std::string> paramTypes;
            for (const auto &param : it->second.params)
            {
                paramTypes.push_back(param.type);
            }
            return paramTypes;
        }

        // Search in parent scope
        if (parent != nullptr)
        {
            return parent->getFunParams(funName);
        }

        return std::vector<std::string>(); // Function not found
    }
};

#endif