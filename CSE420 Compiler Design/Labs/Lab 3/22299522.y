%{

#include "symbol_table.h"

#define YYSTYPE symbol_info*

extern FILE *yyin;
int yyparse(void);
int yylex(void);
extern YYSTYPE yylval;

int lines = 1;

ofstream outlog;
ofstream outerr;
int error_count = 0;

symbol_table *symtbl = nullptr;
string activeType = "";
vector<pair<string,int>> varCollection;
vector<pair<string,string>> paramCollection;
string funcName = "";
string funcReturnType = "";
bool insertParamsToNextScope = false;

#define getname get_name

// you may declare other necessary variables here to store necessary info
// such as current variable type, variable list, function name, return type, function parameter types, parameters names etc.

void log_error(const string &message, int line_no = -1)
{
	int report_line = (line_no >= 0) ? line_no : lines;

	outerr << "At line no: " << report_line << " " << message << endl << endl;
	outlog << "At line no: " << report_line << " " << message << endl << endl;

	error_count++;
}

void insert_params_to_scope(int scope_line)
{
	if (!insertParamsToNextScope) {
		return;
	}

	for (auto &pc : paramCollection)
	{
		if (pc.second.empty())
		{
			continue;
		}

		symbol_info *ps = new symbol_info(pc.second, "ID");
		ps->set_data_type(pc.first);
		ps->set_symbol_kind("variable");
		if (!symtbl->insert(ps)) {
			log_error("Multiple declaration of variable " + pc.second + " in parameter of " + funcName, scope_line);
			delete ps;
		}
	}
	insertParamsToNextScope = false;
}

string infer_type(const string &left, const string &right)
{
	if (left == "error" || right == "error") return "error";
	if (left == "float" || right == "float") return "float";
	if (left == "int" || right == "int") return "int";
	return "void";
}

bool is_zero_literal(const string &text)
{
	char *end = nullptr;
	double value = strtod(text.c_str(), &end);

	return end != text.c_str() &&
		   *end == '\0' &&
		   value == 0.0;
}

void yyerror(char *s)
{
	log_error(s);
}

%}

%token IF ELSE FOR WHILE DO BREAK INT CHAR FLOAT DOUBLE VOID RETURN SWITCH CASE DEFAULT CONTINUE PRINTLN ADDOP MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COMMA SEMICOLON CONST_INT CONST_FLOAT ID

%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
	{
		outlog<<"At line no: "<<lines<<" start : program "<<endl<<endl;
		outlog<<"Symbol Table"<<endl<<endl;
		
		// Print your whole symbol table here
		if(symtbl) symtbl->print_all_scopes(outlog);
	}
	;

program : program unit
	{
		outlog<<"At line no: "<<lines<<" program : program unit "<<endl<<endl;
		outlog<<$1->getname()+"\n"+$2->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+"\n"+$2->getname(),"program");
	}
	| unit
	{
		outlog<<"At line no: "<<lines<<" program : unit "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"program");
	}
	;

	unit : variable_decl
		{
			outlog<<"At line no: "<<lines<<" unit : variable_decl "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"unit");
		}
		| func_definition
		{
			outlog<<"At line no: "<<lines<<" unit : func_definition "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"unit");
		}
		;

	func_definition : type_specifier ID LPAREN param_list RPAREN
		{ 
			funcReturnType = $1->getname();
			funcName = $2->getname();
			insertParamsToNextScope = true;
			
			symbol_info *f = new symbol_info($2->getname(), "ID");
			f->set_symbol_kind("function");
			f->set_data_type($1->getname());
			f->set_parameters(paramCollection);
			if (!symtbl->insert(f))
			{
				log_error(
					"Multiple declaration of function " +$2->getname());

				delete f;
			}
		}
		compound_statement
		{   
			outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN param_list RPAREN compound_statement "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<"("<<$4->getname()<<")\n"<<$7->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+"("+$4->getname()+")\n"+$7->getname(),"func_def");
			
			paramCollection.clear();
			funcName = "";
			funcReturnType = "";
		}
		| type_specifier ID LPAREN RPAREN
		{
			funcReturnType = $1->getname();
			funcName = $2->getname();
			paramCollection.clear();
			insertParamsToNextScope = true;

			symbol_info *f = new symbol_info($2->getname(), "ID");
			f->set_symbol_kind("function");
			f->set_data_type($1->getname());
			if (!symtbl->insert(f))
			{
				log_error(
					"Multiple declaration of function " +$2->getname());

				delete f;
			}
		}
		compound_statement
		{
			outlog<<"At line no: "<<lines<<" func_definition : type_specifier ID LPAREN RPAREN compound_statement "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<"()\n"<<$6->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+"()\n"+$6->getname(),"func_def");
			
			funcName = "";
			funcReturnType = "";
		}
	;

	param_list : param_list COMMA type_specifier ID
		{
			outlog<<"At line no: "<<lines<<" param_list : param_list COMMA type_specifier ID "<<endl<<endl;
			outlog<<$1->getname()<<","<<$3->getname()<<" "<<$4->getname()<<endl<<endl;
					
			$$ = new symbol_info($1->getname()+","+$3->getname()+" "+$4->getname(),"param_list");
            paramCollection.push_back(make_pair($3->getname(), $4->getname()));
			
            // store the necessary information about the function parameters
            // They will be needed when you want to enter the function into the symbol table
		}
		| param_list COMMA type_specifier
		{
			outlog<<"At line no: "<<lines<<" param_list : param_list COMMA type_specifier "<<endl<<endl;
			outlog<<$1->getname()<<","<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+","+$3->getname(),"param_list");
			
			paramCollection.push_back(make_pair($3->getname(), ""));
            // store the necessary information about the function parameters
            // They will be needed when you want to enter the function into the symbol table
		}
 		| type_specifier ID
 		{
			outlog<<"At line no: "<<lines<<" param_list : type_specifier ID "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname(),"param_list");
            paramCollection.clear();
            paramCollection.push_back(make_pair($1->getname(), $2->getname()));
			
            // store the necessary information about the function parameters
            // They will be needed when you want to enter the function into the symbol table
		}
		| type_specifier
		{
			outlog<<"At line no: "<<lines<<" param_list : type_specifier "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"param_list");
            paramCollection.clear();

			paramCollection.push_back(make_pair($1->getname(), ""));
			
            // store the necessary information about the function parameters
            // They will be needed when you want to enter the function into the symbol table
		}
 		;

	compound_statement : LCURL
		{
			int scope_line = lines-1;
			symtbl->enter_scope();
			outlog 	<< "New ScopeTable with ID "
					<< symtbl->get_current_scope_id()
					<< " created"
					<< endl << endl;
			insert_params_to_scope(scope_line);
		}
		statements RCURL
		{
			outlog << "At line no: " << lines
				<< " compound_statement : LCURL statements RCURL "
				<< endl << endl;

			$$ = new symbol_info(
				"{\n" + $3->getname() + "\n}",
				"comp_stmnt"
			);

			outlog << $$->getname() << endl << endl;

			symtbl->print_all_scopes(outlog);

			outlog << "Scopetable with ID "
				<< symtbl->get_current_scope_id()
				<< " removed"
				<< endl << endl;

			symtbl->exit_scope();
		}
		| LCURL
		{
			int scope_line = lines;
			symtbl->enter_scope();
			outlog 	<< "New ScopeTable with ID "
       				<< symtbl->get_current_scope_id()
       				<< " created"
       				<< endl << endl;
			insert_params_to_scope(scope_line);
		}
		RCURL
		{
			outlog << "At line no: " << lines
				<< " compound_statement : LCURL RCURL "
				<< endl << endl;

			$$ = new symbol_info(
				"{\n}",
				"comp_stmnt"
			);

			outlog << $$->getname() << endl << endl;

			symtbl->print_all_scopes(outlog);

			outlog << "Scopetable with ID "
				<< symtbl->get_current_scope_id()
				<< " removed"
				<< endl << endl;

			symtbl->exit_scope();
		}
		;
 		    
	variable_decl : type_specifier declaration_list SEMICOLON
		 {
		outlog<<"At line no: "<<lines<<" variable_decl : type_specifier declaration_list SEMICOLON "<<endl<<endl;
			outlog<<$1->getname()<<" "<<$2->getname()<<";"<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+" "+$2->getname()+";","var_dec");
			
		// Insert necessary information about the variables in the symbol table
		if ($1->getname() == "void") {
			log_error("variable type can not be void ");
		}
		for (auto &vc : varCollection) {
			symbol_info *vs = new symbol_info(vc.first, "ID");
			if (vc.second >= 0) {
				vs->set_symbol_kind("array");
				vs->set_array_size(vc.second);
			} else {
				vs->set_symbol_kind("variable");
			}
			vs->set_data_type($1->getname() == "void" ? "error" : $1->getname());
			if (!symtbl->insert(vs)) {
				log_error("Multiple declaration of variable " + vc.first);
				delete vs;
			}
		}
		varCollection.clear();
		}
 		;

type_specifier : INT
		{
			outlog<<"At line no: "<<lines<<" type_specifier : INT "<<endl<<endl;
			outlog<<"int"<<endl<<endl;
			
		activeType = "int";
			$$ = new symbol_info("int","type");
	    }
 		| FLOAT
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : FLOAT "<<endl<<endl;
			outlog<<"float"<<endl<<endl;
			
		activeType = "float";
			$$ = new symbol_info("float","type");
	    }
 		| VOID
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : VOID "<<endl<<endl;
			outlog<<"void"<<endl<<endl;
			
		activeType = "void";
			$$ = new symbol_info("void","type");
	    }
		| CHAR
 		{
			outlog<<"At line no: "<<lines<<" type_specifier : CHAR "<<endl<<endl;
			outlog<<"char"<<endl<<endl;
			
		activeType = "char";
			$$ = new symbol_info("char","type");
	    }
 		;

declaration_list : declaration_list COMMA ID
		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID "<<endl<<endl;
 		  	outlog<<$1->getname()+","<<$3->getname()<<endl<<endl;

			varCollection.push_back(make_pair($3->getname(), -1));
			$$ = new symbol_info($1->getname()+","+$3->getname(),"decl_list");

			// collect variable names for later insertion into the symbol table
 		  }
 		  | declaration_list COMMA ID LTHIRD CONST_INT RTHIRD //array after some declaration
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
 		  	outlog<<$1->getname()+","<<$3->getname()<<"["<<$5->getname()<<"]"<<endl<<endl;

			varCollection.push_back(make_pair($3->getname(), stoi($5->getname())));
			$$ = new symbol_info($1->getname()+","+$3->getname()+"["+$5->getname()+"]","decl_list");

			// collect array variables with size information for symbol insertion
 		  }
 		  |ID
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;

			varCollection.clear();
			varCollection.push_back(make_pair($1->getname(), -1));
			$$ = new symbol_info($1->getname(),"decl_list");

			// start a new declaration collection for this declaration list
 		  }
 		  | ID LTHIRD CONST_INT RTHIRD //array
 		  {
 		  	outlog<<"At line no: "<<lines<<" declaration_list : ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
			outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;

			varCollection.clear();
			varCollection.push_back(make_pair($1->getname(), stoi($3->getname())));
			$$ = new symbol_info($1->getname()+"["+$3->getname()+"]","decl_list");

			// start a new declaration collection for this array declaration list
 		  }
 		  ;
 		  

statements : statement
	{
		outlog<<"At line no: "<<lines<<" statements : statement "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"stmnts");
	}
	| statements statement
	{
		outlog<<"At line no: "<<lines<<" statements : statements statement "<<endl<<endl;
		outlog<<$1->getname()<<"\n"<<$2->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+"\n"+$2->getname(),"stmnts");
	}
	;
	   
statement : variable_decl
	{
		outlog<<"At line no: "<<lines<<" statement : variable_decl "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"stmnt");
	}
	| expression_statement
	{
		outlog<<"At line no: "<<lines<<" statement : expression_statement "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"stmnt");
	}
	| compound_statement
	{
		outlog<<"At line no: "<<lines<<" statement : compound_statement "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"stmnt");
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement
	{
		outlog<<"At line no: "<<lines<<" statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement "<<endl<<endl;
		outlog<<"for("<<$3->getname()<<$4->getname()<<$5->getname()<<")\n"<<$7->getname()<<endl<<endl;
		
		$$ = new symbol_info("for("+$3->getname()+$4->getname()+$5->getname()+")\n"+$7->getname(),"stmnt");
	}
	| DO statement WHILE LPAREN expression RPAREN SEMICOLON
	{
		outlog<<"At line no: "<<lines<<" statement : DO statement WHILE LPAREN expression RPAREN SEMICOLON "<<endl<<endl;
		outlog<<"do\n"<<$2->getname()<<"while("<<$5->getname()<<");"<<endl<<endl;
		$$ = new symbol_info("do\n"+$2->getname()+"while("+$5->getname()+");","stmnt");
	}
	| BREAK SEMICOLON
	{
		outlog<<"At line no: "<<lines<<" statement : BREAK SEMICOLON "<<endl<<endl;
		outlog<<"break;"<<endl<<endl;
		$$ = new symbol_info("break;","stmnt");
	}
	| CONTINUE SEMICOLON
	{
		outlog<<"At line no: "<<lines<<" statement : CONTINUE SEMICOLON "<<endl<<endl;
		outlog<<"continue;"<<endl<<endl;
		$$ = new symbol_info("continue;","stmnt");
	}
	| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	{
		outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement "<<endl<<endl;
		outlog<<"if("<<$3->getname()<<")\n"<<$5->getname()<<endl<<endl;
		
		$$ = new symbol_info("if("+$3->getname()+")\n"+$5->getname(),"stmnt");
	}
	| IF LPAREN expression RPAREN statement ELSE statement
	{
		outlog<<"At line no: "<<lines<<" statement : IF LPAREN expression RPAREN statement ELSE statement "<<endl<<endl;
		outlog<<"if("<<$3->getname()<<")\n"<<$5->getname()<<"\nelse\n"<<$7->getname()<<endl<<endl;
		
		$$ = new symbol_info("if("+$3->getname()+")\n"+$5->getname()+"\nelse\n"+$7->getname(),"stmnt");
	}
	| WHILE LPAREN expression RPAREN statement
	{
		outlog<<"At line no: "<<lines<<" statement : WHILE LPAREN expression RPAREN statement "<<endl<<endl;
		outlog<<"while("<<$3->getname()<<")\n"<<$5->getname()<<endl<<endl;
		
		$$ = new symbol_info("while("+$3->getname()+")\n"+$5->getname(),"stmnt");
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON
	{
		outlog<<"At line no: "<<lines<<" statement : PRINTLN LPAREN ID RPAREN SEMICOLON "<<endl<<endl;
		outlog<<"printf("<<$3->getname()<<");"<<endl<<endl; 
		
		$$ = new symbol_info("printf("+$3->getname()+");","stmnt");
		symbol_info temp($3->getname(), "ID");
		if (symtbl->lookup(&temp) == nullptr) {
			log_error("Undeclared variable " + $3->getname());
		}
	}
	| RETURN expression SEMICOLON
	{
		outlog<<"At line no: "<<lines<<" statement : RETURN expression SEMICOLON "<<endl<<endl;
		outlog<<"return "<<$2->getname()<<";"<<endl<<endl;
		
		$$ = new symbol_info("return "+$2->getname()+";","stmnt");
	}
	;
	  
expression_statement : SEMICOLON
			{
				outlog<<"At line no: "<<lines<<" expression_statement : SEMICOLON "<<endl<<endl;
				outlog<<";"<<endl<<endl;
				
				$$ = new symbol_info(";","expr_stmt");
	        }			
			| expression SEMICOLON 
			{
				outlog<<"At line no: "<<lines<<" expression_statement : expression SEMICOLON "<<endl<<endl;
				outlog<<$1->getname()<<";"<<endl<<endl;
				
				$$ = new symbol_info($1->getname()+";","expr_stmt");
				$$->set_data_type($1->get_data_type());
	        }
			;
	  
variable : ID 	
      {
	    outlog<<"At line no: "<<lines<<" variable : ID "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"varbl");
		symbol_info temp($1->getname(), "ID");
		symbol_info *existing = symtbl->lookup(&temp);
		if (existing == nullptr) {
			log_error("Undeclared variable " + $1->getname());
			$$->set_data_type("error");
		} else if (existing->get_symbol_kind() == "array") {
			log_error("variable is of array type : " + $1->getname());
			$$->set_data_type("error");
		} else {
			$$->set_data_type(existing->get_data_type());
		}
	 } 	
	 | ID LTHIRD expression RTHIRD 
	 {
	 	outlog<<"At line no: "<<lines<<" variable : ID LTHIRD expression RTHIRD "<<endl<<endl;
		outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+"["+$3->getname()+"]","varbl");
		symbol_info temp($1->getname(), "ID");
		symbol_info *existing = symtbl->lookup(&temp);
		if (existing == nullptr) {
			log_error("Undeclared variable " + $1->getname());
			$$->set_data_type("error");
		} else if (existing->get_symbol_kind() != "array") {
			log_error("variable is not of array type : " + $1->getname());
			$$->set_data_type("error");
		} else
		{
			string indexType = $3->get_data_type();

			if (indexType == "error")
			{
				$$->set_data_type("error");
			}
			else if (indexType != "int")
			{
				log_error(
					"array index is not of integer type : " +
					$1->getname()
				);

				$$->set_data_type("error");
			}
			else
			{
				$$->set_data_type(
					existing->get_data_type()
				);
			}
		}
	}
	;
	 
expression : logic_expression
	   {
	    	outlog<<"At line no: "<<lines<<" expression : logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"expr");
			$$->set_data_type($1->get_data_type());
	   }
	   | variable ASSIGNOP logic_expression 	
	   {
	    	outlog<<"At line no: "<<lines<<" expression : variable ASSIGNOP logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<"="<<$3->getname()<<endl<<endl;

			$$ = new symbol_info($1->getname()+"="+$3->getname(),"expr");
			$$->set_data_type($1->get_data_type());
			string leftType = $1->get_data_type();
			string rightType = $3->get_data_type();

			if (leftType == "error" || rightType == "error")
			{
				$$->set_data_type("error");
			}
			else if (leftType == "void" || rightType == "void")
			{
				log_error("operation on void type ");
				$$->set_data_type("error");
			}
			else if (leftType == "int" && rightType == "float")
			{
				log_error(
					"Warning: Assignment of float value into variable of integer type "
				);

				$$->set_data_type("int");
			}
	   }
	   ;
			
logic_expression : rel_expression
		{
			outlog<<"At line no: "<<lines<<" logic_expression : rel_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"lgc_expr");
			$$->set_data_type($1->get_data_type());
			}	
			| rel_expression LOGICOP rel_expression 
			{
			outlog<<"At line no: "<<lines<<" logic_expression : rel_expression LOGICOP rel_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"lgc_expr");
			string leftType = $1->get_data_type();
			string rightType = $3->get_data_type();

			if (leftType == "error" || rightType == "error")
			{
				$$->set_data_type("error");
			}
			else if (leftType == "void" || rightType == "void")
			{
				log_error("operation on void type ");
				$$->set_data_type("error");
			}
			else
			{
				$$->set_data_type("int");
			}
		}	
		;
			
rel_expression	: simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"rel_expr");
			$$->set_data_type($1->get_data_type());
	    }
		| simple_expression RELOP simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression RELOP simple_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"rel_expr");
			string leftType = $1->get_data_type();
			string rightType = $3->get_data_type();

			if (leftType == "error" || rightType == "error")
			{
				$$->set_data_type("error");
			}
			else if (leftType == "void" || rightType == "void")
			{
				log_error("operation on void type ");
				$$->set_data_type("error");
			}
			else
			{
				$$->set_data_type("int");
			}
	    }
		;
				
simple_expression : term
	{
		outlog<<"At line no: "<<lines<<" simple_expression : term "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"simp_expr");
		$$->set_data_type($1->get_data_type());
	}
	| simple_expression ADDOP term 
	{
		outlog<<"At line no: "<<lines<<" simple_expression : simple_expression ADDOP term "<<endl<<endl;
		outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"simp_expr");
		string leftType = $1->get_data_type();
		string rightType = $3->get_data_type();

		if (leftType == "error" || rightType == "error")
		{
			$$->set_data_type("error");
		}
		else if (leftType == "void" || rightType == "void")
		{
			log_error("operation on void type ");
			$$->set_data_type("error");
		}
		else
		{
			$$->set_data_type(
				infer_type(leftType, rightType)
			);
		}
	}
	;
					
term :	unary_expression
	{
		outlog<<"At line no: "<<lines<<" term : unary_expression "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"term");
		$$->set_data_type($1->get_data_type());
	}
	|  term MULOP unary_expression
	{
		outlog<<"At line no: "<<lines<<" term : term MULOP unary_expression "<<endl<<endl;
		outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"term");
		string leftType = $1->get_data_type();
		string rightType = $3->get_data_type();

		if ($2->getname() == "%")
		{
			$$->set_data_type("int");
		} else if ($2->getname() == "/")
		{
			if (leftType == "error" || rightType == "error")
			{
				$$->set_data_type("error");
			}
			else if (leftType == "void" || rightType == "void")
			{
				log_error("operation on void type ");
				$$->set_data_type("error");
			}
			else if (is_zero_literal($3->getname()))
			{
				log_error("Division by 0 ");
				$$->set_data_type("error");
			}
			else
			{
				$$->set_data_type(
					leftType == "float" || rightType == "float"
					? "float"
					: "int"
				);
			}
		} else {
			if (leftType == "error" || rightType == "error")
			{
				$$->set_data_type("error");
			}
			else if (leftType == "void" || rightType == "void")
			{
				log_error("operation on void type ");
				$$->set_data_type("error");
			}
			else
			{
				$$->set_data_type(
					leftType == "float" || rightType == "float"
					? "float"
					: "int"
				);
			}
		}
	}
	;

unary_expression : ADDOP unary_expression
	{
		outlog<<"At line no: "<<lines<<" unary_expression : ADDOP unary_expression "<<endl<<endl;
		outlog<<$1->getname()<<$2->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+$2->getname(),"un_expr");
		string operandType = $2->get_data_type();

		if (operandType == "error")
		{
			$$->set_data_type("error");
		}
		else if (operandType == "void")
		{
			log_error("operation on void type ");
			$$->set_data_type("error");
		}
		else
		{
			$$->set_data_type(operandType);
		}
	}
	| NOT unary_expression 
	{
		outlog<<"At line no: "<<lines<<" unary_expression : NOT unary_expression "<<endl<<endl;
		outlog<<"!"<<$2->getname()<<endl<<endl;
		
		$$ = new symbol_info("!"+$2->getname(),"un_expr");
		string operandType = $2->get_data_type();

		if (operandType == "error")
		{
			$$->set_data_type("error");
		}
		else if (operandType == "void")
		{
			log_error("operation on void type ");
			$$->set_data_type("error");
		}
		else
		{
			$$->set_data_type("int");
		}
	}
	| factor_info  
	{
		outlog<<"At line no: "<<lines<<" unary_expression : factor_info "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
		
		$$ = new symbol_info($1->getname(),"un_expr");
		$$->set_data_type($1->get_data_type());
	}
	;

factor_info : factor	{
	    outlog<<"At line no: "<<lines<<" factor_info : factor "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr_info");
	}
	;	

factor : variable
    {
	    outlog<<"At line no: "<<lines<<" factor : variable "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
		$$->set_data_type($1->get_data_type());
	}
	| ID LPAREN argument_list RPAREN
	{
	    outlog<<"At line no: "<<lines<<" factor : ID LPAREN argument_list RPAREN "<<endl<<endl;
		outlog<<$1->getname()<<"("<<$3->getname()<<")"<<endl<<endl;

		$$ = new symbol_info($1->getname()+"("+$3->getname()+")","fctr");
		symbol_info temp($1->getname(), "ID");
		symbol_info *existing = symtbl->lookup(&temp);
		if (existing == nullptr) {
			log_error("Undeclared function: " + $1->getname());
			$$->set_data_type("error");
		} else if (existing->get_symbol_kind() != "function") {
			log_error($1->getname() + " is not a function");
			$$->set_data_type("error");
		} else {
			$$->set_data_type(existing->get_data_type());
			vector<pair<string, string>> params =
			existing->get_parameters();

		vector<pair<string, string>> arguments =
			$3->get_parameters();

		if (params.size() != arguments.size())
		{
			log_error(
				"Inconsistencies in number of arguments in function call: " +
				$1->getname()
			);
		}
		else
		{
			for (size_t i = 0; i < arguments.size(); ++i)
			{
				string argumentType = arguments[i].first;
				string parameterType = params[i].first;

				if (argumentType != "error" &&
					argumentType != parameterType)
				{
					log_error(
						"argument " +
						to_string(i + 1) +
						" type mismatch in function call: " +
						$1->getname()
					);
				}
			}
		}
		}
	}
	| LPAREN expression RPAREN
	{
	   	outlog<<"At line no: "<<lines<<" factor : LPAREN expression RPAREN "<<endl<<endl;
		outlog<<"("<<$2->getname()<<")"<<endl<<endl;
		
		$$ = new symbol_info("("+$2->getname()+")","fctr");
		$$->set_data_type($2->get_data_type());
	}
	| CONST_INT 
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_INT "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
		$$->set_data_type("int");
	}
	| CONST_FLOAT
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_FLOAT "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
		$$->set_data_type("float");
	}
	| variable INCOP 
	{
	    outlog<<"At line no: "<<lines<<" factor : variable INCOP "<<endl<<endl;
		outlog<<$1->getname()<<"++"<<endl<<endl;
			
		$$ = new symbol_info($1->getname()+"++","fctr");
		$$->set_data_type($1->get_data_type());
	}
	| variable DECOP
	{
	    outlog<<"At line no: "<<lines<<" factor : variable DECOP "<<endl<<endl;
		outlog<<$1->getname()<<"--"<<endl<<endl;
			
		$$ = new symbol_info($1->getname()+"--","fctr");
		$$->set_data_type($1->get_data_type());
	}
	;
	
argument_list : arguments
	{
		outlog<<"At line no: "<<lines<<" argument_list : arguments "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"arg_list");
		$$->set_parameters($1->get_parameters());
	}
	|
	{
		outlog<<"At line no: "<<lines<<" argument_list :  "<<endl<<endl;
		outlog<<""<<endl<<endl;
			
		$$ = new symbol_info("","arg_list");
	}
	;
	
arguments : arguments COMMA logic_expression
	{
		outlog<<"At line no: "<<lines<<" arguments : arguments COMMA logic_expression "<<endl<<endl;
		outlog<<$1->getname()<<","<<$3->getname()<<endl<<endl;
				
		$$ = new symbol_info($1->getname()+","+$3->getname(),"arg");

		string argumentType = $3->get_data_type();

		if (argumentType == "void")
		{
			log_error("operation on void type ");
			argumentType = "error";
		}

		vector<pair<string, string>> argumentTypes = $1->get_parameters();

		argumentTypes.push_back(
			make_pair(
				argumentType,
				""
			)
		);

		$$->set_parameters(argumentTypes);
	}
	| logic_expression
	{
		outlog<<"At line no: "<<lines<<" arguments : logic_expression "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
				
		$$ = new symbol_info($1->getname(),"arg");

		string argumentType = $1->get_data_type();

		if (argumentType == "void")
		{
			log_error("operation on void type ");
			argumentType = "error";
		}

		vector<pair<string, string>> argumentTypes;

		argumentTypes.push_back(
			make_pair(
				argumentType,
				""
			)
		);

		$$->set_parameters(argumentTypes);
	}
	;
 

%%

int main(int argc, char *argv[])
{
	if(argc != 2) 
	{
		cout<<"Please input file name"<<endl;
		return 0;
	}
	yyin = fopen(argv[1], "r");
	outlog.open("22299522_log.txt", ios::trunc);
	outerr.open("22299522_error.txt", ios::trunc);
	
	if(yyin == NULL)
	{
		cout<<"Couldn't open file"<<endl;
		return 0;
	}
	
	symtbl = new symbol_table(10);

	outlog 	<< "New ScopeTable with ID "
			<< symtbl->get_current_scope_id()
			<< " created"
			<< endl << endl;

	yyparse();
	
	outlog<<endl<<"Total lines: "<<lines<<endl;
	outlog<<"Total errors: "<<error_count<<endl;
	outerr<<"Total errors: "<<error_count<<endl;
	
	outlog.close();
	outerr.close();
	
	fclose(yyin);
	delete symtbl;
	
	return 0;
}
