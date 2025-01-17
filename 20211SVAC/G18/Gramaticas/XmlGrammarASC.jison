 /*---------------------------IMPORTS-------------------------------*/
%{
    let valDeclaration = '';
    let valTag = '';
    let valInside = '';

    const {Error_} = require('../Error');
    const {errores} = require('../Errores');
    const {NodoXML} = require('../Nodes/NodoXml')
%}

/*----------------------------LEXICO-------------------------------*/
%lex
%options case-sensitive
%x xmloptions
%x tagval1
%x tagval2
%x valin

%%
"<?xml"                        %{ this.begin("xmloptions");%}
<xmloptions>"?>"               %{ 
                                    this.popState();
                                    console.log("xmloptions: "+valDeclaration);
                                    yytext = valDeclaration;
                                    valDeclaration = '';
                                    return 'tk_xmldec';
                               %}
<xmloptions>[^(\?>)]           %{ valDeclaration += yytext %}
<xmloptions><<EOF>>            %{ this.popState(); return 'EOF'; %}

["]                             %{ this.begin("tagval1"); %}   
<tagval1>["]                    %{ 
                                    this.popState(); 
                                    console.log("valtag: "+valTag); 
                                    yytext=valTag; valTag=""; 
                                    return 'tk_tagval';
                                %} 
<tagval1>"&lt;"                 %{ valTag +='<'; %}
<tagval1>"&gt;"                 %{ valTag +='>'; %}
<tagval1>"&amp;"                %{ valTag +='&'; %}
<tagval1>"&apos;"               %{ valTag +='\''; %}
<tagval1>"&quot;"               %{ valTag +='\"'; %}
<tagval1>.                      %{ valTag += yytext; %}

[']                             %{ this.begin("tagval2"); %}   
<tagval2>[']                    %{ 
                                    this.popState(); 
                                    console.log("valtag: "+valTag); 
                                    yytext=valTag; valTag=""; 
                                    return 'tk_tagval';
                                %} 
<tagval2>"&lt;"                 %{ valTag +='<'; %}
<tagval2>"&gt;"                 %{ valTag +='>'; %}
<tagval2>"&amp;"                %{ valTag +='&'; %}
<tagval2>"&apos;"               %{ valTag +='\''; %}
<tagval2>"&quot;"               %{ valTag +='\"'; %}
<tagval2>.                      %{ valTag += yytext; %}

">"                             %{ this.begin("valin"); console.log(yytext); return 'tk_endtag';%}
<valin>"<"                      %{ 
                                    this.popState();
                                    console.log('<');
                                    return 'tk_starttag';
                                %}
<valin>[^<]+                    %{ console.log("valin: "+yytext); return 'tk_valin'; %}
<valin><<EOF>>                  %{ this.popState(); return 'EOF'; %}

">"                             %{ console.log(yytext); return 'tk_endtag'; %}
"<"                             %{ console.log(yytext); return 'tk_starttag'; %}
"/"                             %{ console.log(yytext); return 'tk_closetag'; %}                
"="                             %{ console.log(yytext); return 'tk_igual'; %}                                


[[a-zA-ZñÑáéíóúÁÉÍÓÚ]["_""-"0-9a-zA-ZñÑáéíóúÁÉÍÓÚ]*|["_""-"]+[0-9a-zA-ZñÑáéíóúÁÉÍÓÚ]["_""-"0-9a-zA-ZñÑáéíóúÁÉÍÓÚ]*] %{  console.log("id:"+yytext); return 'tk_id'; %}


[ \t\n\r\f] 		%{ /*se ignoran*/ %}
<<EOF>>             %{  return 'EOF';  %}

.                   %{ errores.push(new Error_(yylloc.first_line, yylloc.first_column, 'Lexico','Valor inesperado ' + yytext)); console.error(errores); %}


/lex
/*-------------------------SINTACTICO------------------------------*/
/*-----ASOCIACION Y PRECEDENCIA-----*/
/*----------ESTADO INICIAL----------*/
%start S
%% 
%locations
/*-------------GRAMATICA------------*/
S: tk_xmldec I EOF  { 
                        var s = new NodoXML("S","S",@2.first_line+1,@2.first_column+1);
                        var dec = new NodoXML($1,"DEC",@1.first_line+1,@1.first_column+1);
                        s.addHijo(dec);
                        s.addHijo($2);
                        return s;
                    }
|I EOF  { 
            var s = new NodoXML("S","S",@1.first_line+1,+@1.first_column+1); 
            s.addHijo($1);
            return s;
        }
;

I:OTAG CONTENIDO CTAG  {
                            var i = new NodoXML("I","I",@1.first_line+1,+@1.first_column+1); 
                            i.addHijo($1);
                            i.addHijo($2);
                            i.addHijo($3);
                            $$ = i;
                        }
|OTAG CTAG  {
                var i = new NodoXML("I","I",@1.first_line+1,+@1.first_column+1); 
                i.addHijo($1);
                i.addHijo($2);
                $$ = i;
            }
;

OTAG: tk_starttag tk_id tk_endtag   {
                                        $$ = new NodoXML($2,'OTAG',@1.first_line+1,+@1.first_column+1);
                                    }
|tk_starttag tk_id ARGUMENTOS tk_endtag {
                                            var tag = new NodoXML($2,'OTAG',@1.first_line+1,+@1.first_column+1);
                                            tag.addHijo($3);
                                            $$ = tag;
                                        }
;

ARGUMENTOS: ARGUMENTOS tk_id tk_igual tk_tagval {
                                                    var args = new NodoXML('ARGS','ARGS',@1.first_line+1,+@1.first_column+1);
                                                    var arg = new NodoXML($2,'ARG',@2.first_line+1,+@2.first_column+1);
                                                    var val = new NodoXML($4,'VAL',@4.first_line+1,+@4.first_column+1);
                                                    arg.addHijo(val);
                                                    args.addHijo($1);
                                                    args.addHijo(arg);
                                                    $$ = args;
                                                }
| tk_id tk_igual tk_tagval  {
                                var arg = new NodoXML($1,'ARG',@1.first_line+1,+@1.first_column+1);
                                var val = new NodoXML($3,'VAL',@3.first_line+1,+@3.first_column+1);
                                arg.addHijo(val);
                                $$ = arg;
                            }
;

CONTENIDO: CONTENIDO OTAG CONTENIDO CTAG{
                                            var content = new NodoXML('CONTENT','CONTENT',@1.first_line+1,+@1.first_column+1);
                                            content.addHijo($1);
                                            content.addHijo($2);
                                            content.addHijo($3);
                                            content.addHijo($4);
                                            $$ = content;
                                        }
| CONTENIDO OTAG CTAG   {
                            var content = new NodoXML('CONTENT','CONTENT',@1.first_line+1,+@1.first_column+1);
                            content.addHijo($1);
                            content.addHijo($2);
                            content.addHijo($3);
                            $$ = content;
                        }
| CONTENIDO tk_valin{
                        var content = new NodoXML('CONTENT','CONTENT',@1.first_line+1,+@1.first_column+1);
                        var val = new NodoXML($2,'VAL',@2.first_line+1,+@2.first_column+1);
                        content.addHijo($1);
                        content.addHijo(val);
                        $$ = content;
                    }
| OTAG CONTENIDO CTAG   {
                            var content = new NodoXML('CONTENT','CONTENT',@1.first_line+1,+@1.first_column+1);
                            content.addHijo($1);
                            content.addHijo($2);
                            content.addHijo($3);
                            $$ = content;
                        }
| OTAG CTAG {
                var content = new NodoXML('CONTENT','CONTENT',@1.first_line+1,+@1.first_column+1);
                content.addHijo($1);
                content.addHijo($2);
                $$ = content;
            }
| tk_valin  {
                var val = new NodoXML($1,'VAL',@1.first_line+1,+@1.first_column+1);
                $$ = val;
            }
;

CTAG: tk_starttag tk_closetag tk_id tk_endtag   {
                                                    $$ = new NodoXML($3,'CTAG',@1.first_line+1,+@1.first_column+1);
                                                }
;