#include "symbol_info.h"

class scope_table
{
private:
    int bucket_count;
    int unique_id;
    scope_table *parent_scope = NULL;
    vector<list<symbol_info *>> table;

    int hash_function(string name)
    {
        int sum = 0;

        for (char ch : name)
        {
            sum += ch;
        }

        return sum % bucket_count;
    }

public:
    scope_table();
    scope_table(int bucket_count, int unique_id, scope_table *parent_scope);
    scope_table *get_parent_scope();
    int get_unique_id();
    symbol_info *lookup_in_scope(symbol_info* symbol);
    bool insert_in_scope(symbol_info* symbol);
    bool delete_from_scope(symbol_info* symbol);
    void print_scope_table(ofstream& outlog);
    ~scope_table();

};

// Constructor definitions
scope_table::scope_table()
{
    bucket_count = 0;
    unique_id = 0;
    parent_scope = NULL;
}

scope_table::scope_table(int bucket_count, int unique_id, scope_table *parent_scope)
{
    this->bucket_count = bucket_count;
    this->unique_id = unique_id;
    this->parent_scope = parent_scope;
    table.resize(bucket_count);
}

scope_table *scope_table::get_parent_scope()
{
    return parent_scope;
}

int scope_table::get_unique_id()
{
    return unique_id;
}

symbol_info *scope_table::lookup_in_scope(symbol_info* symbol)
{
    if (!symbol) return NULL;
    
    int bucket_idx = hash_function(symbol->get_name());
    for (symbol_info* sym : table[bucket_idx])
    {
        if (sym->get_name() == symbol->get_name())
        {
            return sym;
        }
    }
    return NULL;
}

bool scope_table::insert_in_scope(symbol_info* symbol)
{
    if (!symbol) return false;
    
    // Check if symbol already exists in current scope
    symbol_info tmp(symbol->get_name(), symbol->get_type());
    if (lookup_in_scope(&tmp) != NULL)
    {
        return false;  // Already exists
    }
    
    int bucket_idx = hash_function(symbol->get_name());
    table[bucket_idx].push_back(symbol);
    return true;
}

bool scope_table::delete_from_scope(symbol_info* symbol)
{
    if (!symbol) return false;   
    int bucket_idx = hash_function(symbol->get_name());
    for (auto iter = table[bucket_idx].begin(); iter != table[bucket_idx].end(); ++iter)
    {
        if ((*iter)->get_name() == symbol->get_name())
        {
            delete *iter;
            table[bucket_idx].erase(iter);
            return true;
        }
    }
    return false;
}

scope_table::~scope_table()
{
    for (int i = 0; i < bucket_count; i++)
    {
        for (symbol_info *symbol : table[i])
        {
            delete symbol;
        }
        table[i].clear();
    }

    table.clear();
}

// complete the methods of scope_table class
void scope_table::print_scope_table(ofstream& outlog)
{
    outlog << "ScopeTable # " << unique_id << endl;
    for (int i = 0; i < bucket_count; i++)
    {
        if (table[i].empty())
        {
            continue;
        }
        outlog << i << " --> " << endl;

        for (symbol_info *symbol : table[i])
        {
            outlog << "< " << symbol->get_name()
                   << " : " << symbol->get_type()
                   << " >" << endl;
            if (symbol->get_symbol_kind() == "variable")
            {
                outlog << "Variable" << endl;
                outlog << "Type: " << symbol->get_data_type() << endl;
            }
            else if (symbol->get_symbol_kind() == "array")
            {
                outlog << "Array" << endl;
                outlog << "Type: " << symbol->get_data_type() << endl;
                outlog << "Size: " << symbol->get_array_size() << endl;
            }
            else if (symbol->get_symbol_kind() == "function")
            {
                vector<pair<string, string>> parameters =
                    symbol->get_parameters();
                outlog << "Function Definition" << endl;
                outlog << "Return Type: "
                       << symbol->get_data_type() << endl;
                outlog << "Number of Parameters: "
                       << parameters.size() << endl;
                outlog << "Parameter Details: ";

                for (int j = 0; j < parameters.size(); j++)
                {
                    outlog << parameters[j].first;
                    if (parameters[j].second != "")
                    {
                        outlog << " " << parameters[j].second;
                    }
                    if (j < parameters.size() - 1)
                    {
                        outlog << ", ";
                    }
                }
                outlog << endl;
            }
            outlog << endl;
        }
    }
}