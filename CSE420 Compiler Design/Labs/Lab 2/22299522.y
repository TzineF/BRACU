%{

#include "symbol_table.h"

#define YYSTYPE symbol_info*

extern FILE *yyin;
int yyparse(void);
int yylex(void);
extern YYSTYPE yylval;

int lines = 1;

ofstream outlog;

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

void yyerror(char *s)
{
	outlog<<"At line "<<lines<<" "<<s<<endl<<endl;

    // you may need to reinitialize variables if you find an error
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
			symtbl->insert(f);
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
			symtbl->insert(f);
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
			symtbl->enter_scope();
			outlog 	<< "New ScopeTable with ID "
					<< symtbl->get_current_scope_id()
					<< " created"
					<< endl << endl;
			if (insertParamsToNextScope) {
				for (auto &pc : paramCollection)
				{
					if (pc.second.empty())
					{
						continue;
					}

					symbol_info *ps = new symbol_info(pc.second, "ID");
					ps->set_data_type(pc.first);
					ps->set_symbol_kind("variable");
					symtbl->insert(ps);
				}
				insertParamsToNextScope = false;
			}
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
			symtbl->enter_scope();
			outlog 	<< "New ScopeTable with ID "
       				<< symtbl->get_current_scope_id()
       				<< " created"
       				<< endl << endl;
			if (insertParamsToNextScope) {
				for (auto &pc : paramCollection) {
					if (pc.second.empty())
					{
						continue;
					}

					symbol_info *ps = new symbol_info(pc.second, "ID");
					ps->set_data_type(pc.first);
					ps->set_symbol_kind("variable");
					symtbl->insert(ps);
				}
				insertParamsToNextScope = false;
			}
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
		for (auto &vc : varCollection) {
			symbol_info *vs = new symbol_info(vc.first, "ID");
			if (vc.second >= 0) {
				vs->set_symbol_kind("array");
				vs->set_array_size(vc.second);
			} else {
				vs->set_symbol_kind("variable");
			}
			vs->set_data_type($1->getname());
			symtbl->insert(vs);
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
	        }
			;



variable : ID 	
      {
	    outlog<<"At line no: "<<lines<<" variable : ID "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"varbl");
		
	 }	
	 | ID LTHIRD expression RTHIRD 
	 {
	 	outlog<<"At line no: "<<lines<<" variable : ID LTHIRD expression RTHIRD "<<endl<<endl;
		outlog<<$1->getname()<<"["<<$3->getname()<<"]"<<endl<<endl;
		
		$$ = new symbol_info($1->getname()+"["+$3->getname()+"]","varbl");
	 }
	 ;



expression : logic_expression
	   {
	    	outlog<<"At line no: "<<lines<<" expression : logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"expr");
	   }
	   | variable ASSIGNOP logic_expression 	
	   {
	    	outlog<<"At line no: "<<lines<<" expression : variable ASSIGNOP logic_expression "<<endl<<endl;
			outlog<<$1->getname()<<"="<<$3->getname()<<endl<<endl;

			$$ = new symbol_info($1->getname()+"="+$3->getname(),"expr");
	   }
	   ;


logic_expression : rel_expression
	     {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"lgc_expr");
	     }	
		 | rel_expression LOGICOP rel_expression 
		 {
	    	outlog<<"At line no: "<<lines<<" logic_expression : rel_expression LOGICOP rel_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"lgc_expr");
	     }	
		 ;




rel_expression	: simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"rel_expr");
	    }
		| simple_expression RELOP simple_expression
		{
	    	outlog<<"At line no: "<<lines<<" rel_expression : simple_expression RELOP simple_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"rel_expr");
	    }
		;




simple_expression : term
          {
	    	outlog<<"At line no: "<<lines<<" simple_expression : term "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"simp_expr");
			
	      }
		  | simple_expression ADDOP term 
		  {
	    	outlog<<"At line no: "<<lines<<" simple_expression : simple_expression ADDOP term "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"simp_expr");
	      }
		  ;
					
term :	unary_expression //term can be void because of un_expr->factor
     {
	    	outlog<<"At line no: "<<lines<<" term : unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"term");
	 }
     |  term MULOP unary_expression
     {
	    	outlog<<"At line no: "<<lines<<" term : term MULOP unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<$3->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname()+$3->getname(),"term");
	 }
     ;

unary_expression : ADDOP unary_expression  // un_expr can be void because of factor
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : ADDOP unary_expression "<<endl<<endl;
			outlog<<$1->getname()<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname()+$2->getname(),"un_expr");
	     }
		 | NOT unary_expression 
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : NOT unary_expression "<<endl<<endl;
			outlog<<"!"<<$2->getname()<<endl<<endl;
			
			$$ = new symbol_info("!"+$2->getname(),"un_expr");
	     }
		 | factor_info  
		 {
	    	outlog<<"At line no: "<<lines<<" unary_expression : factor_info "<<endl<<endl;
			outlog<<$1->getname()<<endl<<endl;
			
			$$ = new symbol_info($1->getname(),"un_expr");
	     }
		 ;
factor_info : factor	{
	    outlog<<"At line no: "<<lines<<" factor_info : factor "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr_info");
	}	
factor	: variable
    {
	    outlog<<"At line no: "<<lines<<" factor : variable "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
	}
	| ID LPAREN argument_list RPAREN
	{
	    outlog<<"At line no: "<<lines<<" factor : ID LPAREN argument_list RPAREN "<<endl<<endl;
		outlog<<$1->getname()<<"("<<$3->getname()<<")"<<endl<<endl;

		$$ = new symbol_info($1->getname()+"("+$3->getname()+")","fctr");
	}
	| LPAREN expression RPAREN
	{
	   	outlog<<"At line no: "<<lines<<" factor : LPAREN expression RPAREN "<<endl<<endl;
		outlog<<"("<<$2->getname()<<")"<<endl<<endl;
		
		$$ = new symbol_info("("+$2->getname()+")","fctr");
	}
	| CONST_INT 
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_INT "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
	}
	| CONST_FLOAT
	{
	    outlog<<"At line no: "<<lines<<" factor : CONST_FLOAT "<<endl<<endl;
		outlog<<$1->getname()<<endl<<endl;
			
		$$ = new symbol_info($1->getname(),"fctr");
	}
	| variable INCOP 
	{
	    outlog<<"At line no: "<<lines<<" factor : variable INCOP "<<endl<<endl;
		outlog<<$1->getname()<<"++"<<endl<<endl;
			
		$$ = new symbol_info($1->getname()+"++","fctr");
	}
	| variable DECOP
	{
	    outlog<<"At line no: "<<lines<<" factor : variable DECOP "<<endl<<endl;
		outlog<<$1->getname()<<"--"<<endl<<endl;
			
		$$ = new symbol_info($1->getname()+"--","fctr");
	}
	;



argument_list : arguments
			  {
					outlog<<"At line no: "<<lines<<" argument_list : arguments "<<endl<<endl;
					outlog<<$1->getname()<<endl<<endl;
						
					$$ = new symbol_info($1->getname(),"arg_list");
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
		  }
	      | logic_expression
	      {
				outlog<<"At line no: "<<lines<<" arguments : logic_expression "<<endl<<endl;
				outlog<<$1->getname()<<endl<<endl;
						
				$$ = new symbol_info($1->getname(),"arg");
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
	
	if(yyin == NULL)
	{
		cout<<"Couldn't open file"<<endl;
		return 0;
	}
	// Initialize the global scope table before parsing (match Lab02 behavior)
	symtbl = new symbol_table(10);

	outlog 	<< "New ScopeTable with ID "
			<< symtbl->get_current_scope_id()
			<< " created"
			<< endl << endl;

	yyparse();
	
	outlog<<endl<<"Total lines: "<<lines<<endl;
	
	outlog.close();
	
	fclose(yyin);
	delete symtbl;
	



	return 0;
}