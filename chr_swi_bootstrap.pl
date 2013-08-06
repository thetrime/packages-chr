/*  $Id$

    Part of CHR (Constraint Handling Rules)

    Author:        Tom Schrijvers
    E-mail:        Tom.Schrijvers@cs.kuleuven.be
    WWW:           http://www.swi-prolog.org
    Copyright (C): 2003-2004, K.U. Leuven

    This program is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License
    as published by the Free Software Foundation; either version 2
    of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

    As a special exception, if you link this library with other files,
    compiled with a Free Software compiler, to produce an executable, this
    library does not by itself cause the resulting executable to be covered
    by the GNU General Public License. This exception does not however
    invalidate any other reasons why the executable file might be covered by
    the GNU General Public License.
*/

:- module(chr,
	  [ chr_compile_step1/2		% +CHRFile, -PlFile
	  , chr_compile_step2/2		% +CHRFile, -PlFile
	  , chr_compile_step3/2		% +CHRFile, -PlFile
	  , chr_compile_step4/2		% +CHRFile, -PlFile
	  , chr_compile/3
	  ]).
%% SWI begin
% vsc:
:- expects_dialect(swi).

:- if(current_prolog_flag(dialect, yap)).

:- prolog_load_context(directory,D), add_to_path(D).

:- else.

:- use_module(library(listing)). % portray_clause/2

:- endif.

%% SWI end
:- include(chr_op).

		 /*******************************
		 *    FILE-TO-FILE COMPILER	*
		 *******************************/

%	chr_compile(+CHRFile, -PlFile)
%
%	Compile a CHR specification into a Prolog file

chr_compile_step1(From, To) :-
	use_module('chr_translate_bootstrap.pl'),
	chr_compile(From, To, informational).
chr_compile_step2(From, To) :-
	use_module('chr_translate_bootstrap1.pl'),
	chr_compile(From, To, informational).
chr_compile_step3(From, To) :-
	use_module('chr_translate_bootstrap2.pl'),
	chr_compile(From, To, informational).
chr_compile_step4(From, To) :-
	use_module('chr_translate.pl'),
	chr_compile(From, To, informational).

chr_compile(From, To, MsgLevel) :-
	print_message(MsgLevel, chr(start(From))),
	read_chr_file_to_terms(From,Declarations),
	% read_file_to_terms(From, Declarations,
	%		   [ module(chr)	% get operators from here
	%		   ]),
	print_message(silent, chr(translate(From))),
	chr_translate(Declarations, Declarations1),
	insert_declarations(Declarations1, NewDeclarations),
	print_message(silent, chr(write(To))),
	writefile(To, From, NewDeclarations),
	print_message(MsgLevel, chr(end(From, To))).


%% SWI begin
specific_declarations([ (:- use_module('chr_runtime')),
			(:- style_check(-discontiguous)),
			(:- style_check(-singleton))
		      | Tail
		      ], Tail).
%% SWI end

%% SICStus begin
%% specific_declarations([(:- use_module('chr_runtime')),
%%                     (:-use_module(chr_hashtable_store)),
%%		       (:- use_module('hpattvars')),
%%		       (:- use_module('b_globval')),
%%		       (:- use_module('hprolog')),  % needed ?
%%		       (:- set_prolog_flag(discontiguous_warnings,off)),
%%		       (:- set_prolog_flag(single_var_warnings,off))|Tail], Tail).
%% SICStus end



insert_declarations(Clauses0, Clauses) :-
	specific_declarations(Decls,Tail),
	(Clauses0 = [(:- module(M,E))|FileBody] ->
	    Clauses = [ (:- module(M,E))|Decls],
	    Tail = FileBody
	;
	    Clauses = Decls,
	    Tail = Clauses0
	).

%	writefile(+File, +From, +Desclarations)
%
%	Write translated CHR declarations to a File.

writefile(File, From, Declarations) :-
	open(File, write, Out),
	writeheader(From, Out),
	writecontent(Declarations, Out),
	close(Out).

writecontent([], _).
writecontent([D|Ds], Out) :-
	portray_clause(Out, D),		% SWI-Prolog
	writecontent(Ds, Out).


writeheader(File, Out) :-
	format(Out, '/*  Generated by CHR bootstrap compiler~n', []),
	format(Out, '    From: ~w~n', [File]),
	format_date(Out),
	format(Out, '    DO NOT EDIT.  EDIT THE CHR FILE INSTEAD~n', []),
	format(Out, '*/~n~n', []).

%% SWI begin
format_date(Out) :-
	get_time(Now),
	convert_time(Now, Date),
	format(Out, '    Date: ~w~n~n', [Date]).
%% SWI end

%% SICStus begin
%% :- use_module(library(system), [datime/1]).
%% format_date(Out) :-
%%	datime(datime(Year,Month,Day,Hour,Min,Sec)),
%%	format(Out, '    Date: ~d-~d-~d ~d:~d:~d~n~n', [Day,Month,Year,Hour,Min,Sec]).
%% SICStus end



		 /*******************************
		 *	       MESSAGES		*
		 *******************************/


:- multifile
	prolog:message/3.

prolog:message(chr(start(File))) -->
	{ file_base_name(File, Base)
	},
	[ 'Translating CHR file ~w'-[Base] ].
prolog:message(chr(end(_From, To))) -->
	{ file_base_name(To, Base)
	},
	[ 'Written translation to ~w'-[Base] ].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
read_chr_file_to_terms(Spec, Terms) :-
	chr_absolute_file_name(Spec, [ access(read) ], Path),
	open(Path, read, Fd, []),
	read_chr_stream_to_terms(Fd, Terms),
	close(Fd).

read_chr_stream_to_terms(Fd, Terms) :-
	chr_local_only_read_term(Fd, C0, [ module(chr) ]),
	read_chr_stream_to_terms(C0, Fd, Terms).

read_chr_stream_to_terms(end_of_file, _, []) :- !.
read_chr_stream_to_terms(C, Fd, [C|T]) :-
	( ground(C),
	  C = (:- op(Priority,Type,Name)) ->
		op(Priority,Type,Name)
	;
		true
	),
	chr_local_only_read_term(Fd, C2, [module(chr)]),
	read_chr_stream_to_terms(C2, Fd, T).




%% SWI begin
chr_local_only_read_term(A,B,C) :- read_term(A,B,C).
chr_absolute_file_name(A,B,C) :- absolute_file_name(A,B,C).
%% SWI end

%% SICStus begin
%% chr_local_only_read_term(A,B,_) :- read_term(A,B,[]).
%% chr_absolute_file_name(A,B,C) :- absolute_file_name(A,C,B).
%% SICStus end
