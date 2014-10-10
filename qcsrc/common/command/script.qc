.float  script_type;

#include "script/string.qh"
#include "script/ast.qh"
#include "script/lex.qh"
#include "script/parse.qh"

// ========================================================================
//   Command
// ========================================================================

void GenericCommand_script(float request, float argc, string command)
{
	switch(request)
	{
		case CMD_REQUEST_COMMAND:
		{
			string source = "";
			if ( argc == 3 && argv(1) == "file" )
			{
				float file = fopen(argv(2),FILE_READ);
				if ( file < 0 )
				{
					dprint("Script: unable to open file ",argv(2),"\n");
					return;
				}
				dprint("Script: executing ",argv(2),"\n");
				string line;
				while (( line = fgets(file) ))
					source = strcat(source,line,"\n");
				fclose(file);
			}
			else
				source = substring(command, 7, strlen(command));
			entity ast_root = script_compile(source);
			print(strcat(script_evaluate(ast_root).script_value,"\n"));
			script_cleanup(ast_root);
			return;
		}
		
		default:
		case CMD_REQUEST_USAGE:
			print(strcat("\nUsage:^3 ", GetProgramCommandPrefix(), " script EXPRESSION...\n"));
			print(strcat("\nUsage:^3 ", GetProgramCommandPrefix(), " script file filename\n"));
			return;
	}
}