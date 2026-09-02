#include <bits/stdc++.h>
using namespace std;

class symbol_info
{
private:
    string name;
    string type;
    string symbol_kind;   
    string data_type;     
    int array_size;
    vector<pair<string, string>> parameters; 


public:
    symbol_info(string name, string type)
    {
        this->name = name;
        this->type = type;
        this->symbol_kind = "";
        this->data_type = "";
        this->array_size = -1;
    }
    string get_name()
    {
        return name;
    }
    string get_type()
    {
        return type;
    }
    void set_name(string name)
    {
        this->name = name;
    }
    void set_type(string type)
    {
        this->type = type;
    }
    void set_symbol_kind(string symbol_kind)
    {
        this->symbol_kind = symbol_kind;
    }

    string get_symbol_kind()
    {
        return symbol_kind;
    }

    void set_data_type(string data_type)
    {
        this->data_type = data_type;
    }

    string get_data_type()
    {
        return data_type;
    }

    void set_array_size(int array_size)
    {
        this->array_size = array_size;
    }

    int get_array_size()
    {
        return array_size;
    }

    void add_parameter(string parameter_type, string parameter_name)
    {
        parameters.push_back({parameter_type, parameter_name});
    }

    void set_parameters(const vector<pair<string, string>> &params)
    {
        parameters = params;
    }

    vector<pair<string, string>> get_parameters()
    {
        return parameters;
    }
    ~symbol_info()
    {}
};