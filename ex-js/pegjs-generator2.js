module.exports = (function () {

    var generator = { debug: false };

    var template = 'Template\n = StatementInTemplate\n\n';
    var characterStatement = 'CharacterStatement\n = &{}\n\n';
    var macroExpression = 'MacroExpression\n = '
    var macroStatement = 'MacroStatement\n = '
    
    var pegObj2 = {
        // enclosing types
        Brace: { left: '"{"', right: '"}"' },
        Paren: { left: '"("', right: '")"' },
        Bracket: { left: '"["', right: '"]"' },

        // Repetition
        repetition: function(elements, mark) {
            return {
                type: 'Repetition',
                elements: elements,
                mark: mark,
                toCode: function (context) {
                    var template = context === 'template';
                    var m = mark? '__ "' + mark + '" ' : '';
                    return '(head:' + this.elements.toCode(context)
                        + '\n tail:(' + m + '__ ' + this.elements.toCode(context) + ')*\n'
                        + (template? 'ellipsis:(' + m + '__ "...")?\n' : '')
                        + '{ var elements = [head];\n\
for (var i=0; i<tail.length; i++) {\n\
elements.push(tail[i][' + (m? 3 : 1) + ']);\n\
}\n'
                        + (template? 'if (ellipsis) elements.push({ type: "Ellipsis" });\n' : '')
                        + 'return { type: "Repeat", elements: elements };\n\
})?\n';
                },
                toString: function() {
                    return '(head:' + elements + ' tail:(' + (mark? ('__ "' + mark + '" ') : '') + '__ ' + elements + ')*\n\
{ var elements = [head];\n\
for (var i=0; i<tail.length; i++) {\n\
elements.push(tail[i][' + (mark? 3 : 1) + ']);\n\
}\n\
return { type: "Repeat", elements: elements };\n\
})?\n'; }
            };
        },

        // Enclosing
        enclosing: function (type, elements) {
            var isNull = elements.type.charAt(0) === '-';
            if (!isNull)
                elements = pegObj2.tag('t0', elements);
            switch (type) {
            case 'RepBlock':
                return {
                    type: type,
                    elements: elements,
                    toCode: function (context) {
                        return '(' + (isNull? '' : (this.elements.toCode(context) + ' __ ')) + '\n\
{ return { type: "RepBlock", elements: ' + (isNull? '[]' : 't0') + ' }; })';
                    },
                    toString: function () {
                        return '(' + (isNull? '' : (elements + ' __ ')) + '\n\
{ return { type: "RepBlock", elements: ' + (isNull? '[]' : 't0') + ' }; })';
                    }
                };
                break;
            case 'Brace':
            case 'Paren':
            case 'Bracket':
                return {
                    type: type,
                    elements: elements,
                    toCode: function (context) {
                        return '(' + pegObj2[type].left + ' __ ' + (isNull? '' : (this.elements.toCode(context) + ' __ ')) + pegObj2[type].right + '\n\
{ return { type: "' + type + '", elements: ' + (isNull? '[]' : 't0') + ' }; })';
                    },
                    toString: function () {
                        return '(' + pegObj2[type].left + ' __ ' + (isNull? '' : (elements + ' __ ')) + pegObj2[type].right + '\n\
{ return { type: "' + type + '", elements: ' + (isNull? '[]' : 't0') + ' }; })';
                    }
                };
                break;
            }
        },

        // Identifier
        identifier: function () {
            return {
                type: 'Identifier',
                toCode: function (context) { return 'MacroIdentifier'; },
                toString: function () { return 'MacroIdentifier'; }
            };
        },

        // Expression
        expression: function () {
            return {
                type: 'Expression',
                toCode: function (context) { return 'AssignmentExpression'; },
                toString: function () { return 'AssignmentExpression'; }
            };
        },

        // Statement
        statement: function () {
            return {
                type: 'Statement',
                toCode: function (context) { return 'Statement'; },
                toString: function () { return 'Statement'; }
            };
        },

        // symbol
        symbol: function () {
            return {
                type: 'Symbol',
                toCode: function (context) { return 'MacroSymbol'; },
                toString: function () { return 'MacroSymbol'; }
            };
        },

        // keyword
        keyword: function (name) {
            return {
                type: 'LiteralKeyword',
                name: name,
                toCode: function (context) {
                     return '(v:MacroKeyword &{ return v.name === "' + name + '"; }\n\
{ return v; })';
                },
                toString: function () {
                    return '(v:MacroKeyword &{ return v.name === "' + name + '"; }\n\
{ return v; })';
                }
            };
        }, 

        // Punct
        punct: function(type, value) {
            return {
                type: type,
                value: value,
                toCode: function (context) {
                    return '("' + value + '"\n\
{ return { type: "' + type + '", value: "' + value + '" }; })';
                },
                toString: function () { return '("' + value + '"\n\
{ return { type: "' + type + '", value: "' + value + '" }; })'; }
            };
        },

        // Literal
        literal: function(type, value) {
            switch (type) {
            case 'NumericLiteral':
            case 'StringLiteral':
                return {
                    type: type,
                    value: value,
                    toCode: function (context) {
                        return '(v:' + type + ' &{ return eval(v) === ' + value + '; }\n\
{ return { type: "' + type + '", value: v }; })';
                    },
                    toString: function () {
                        return '(v:' + type + ' &{ return eval(v) === ' + value + '; }\n\
{ return { type: "' + type + '", value: v }; })';
                    }
                };
                break;
            case 'BooleanLiteral':
            case 'RegularExpressionLiteral':
                return {
                    type: type,
                    value: value,
                    toCode: function (context) {
                        return '(v:' + type + ' &{ return eval(v.value) === ' + value + '; }\n\
{ return v; })';
                    },
                    toString: function () {
                        return '(v:' + type + ' &{ return eval(v.value) === ' + value + '; }\n\
{ return v; })';
                    }
                };
                break;
            case 'NullLiteral':
                return {
                    type: type,
                    value: value,
                    toCode: function (context) { return 'NullLiteral'; },
                    toString: function () {
                        return 'NullLiteral';
                    }
                };
                break;
            }
        },

        // Macro name
        macroName: function (name) {
            return {
                type: 'MacroName',
                name: name,
                toCode: function (context) {
                    return '("' + name + '" !IdentifierPart\n\
{ return { type: "MacroName", name:"' + name + '" }; })';
                },
                toString: function () {
                    return '("' + name + '" !IdentifierPart\n\
{ return { type: "MacroName", name:"' + name + '" }; })' }
            };
        },

        macroForm: function (name, body) {
            var form = [name];
            for (var i=0; i<body.length; i++) {
                form.push(convertToPegObj(body[i]));
            }
            form = pegObj2.sequence(form);
            return {
                type: 'MacroForm',
                name: name.name,
                inputForm: form,
                toCode: function (context) {
                    var template = context === 'template';
                    return (template? '&{ return macroType; } ' : '')
                        + 'form:' + form.toCode(context) + '\n\
{ return { type: "MacroForm", inputForm: form }; }';
                },
                toString: function () {
                    return 'form:' + form + '\n\
{ return { type: "MacroForm", inputForm: form }; }';
                }
            };
        },

        // Tag (Label)
        tag: function(tag, value) {
            return {
                type: 'Tag',
                value: value,
                tag: tag,
                toCode: function (context) {
                    return tag + ':' + this.value.toCode(context);
                },
                toString: function() { return tag + ':' + value; }
            };
        },

        // Sequence
        sequence: function(array) {
            var newArray = [];
            for (var i=0; i<array.length; i++) {
                if (array[i].type.charAt(0) !== '-')
                    newArray.push(array[i]);
            }
            var result = [];
            var tags = [];
            for (var i=0; i<newArray.length; i++) {
                result.push(pegObj2.tag('t'+i, newArray[i]));
                tags.push('t'+i);
            }
            return {
                type: 'Sequence',
                elements: result,
                toCode: function (context) {
                    var es = [];
                    for (var i=0; i<this.elements.length; i++) {
                        es.push(this.elements[i].toCode(context));
                    }
                    return '(' + es.join(' __ ') + ' { return [' + tags.join(', ') + ']; })';
                },
                toString: function() { return '(' + this.elements.join(' __ ') + ' { return [' + tags.join(', ') + ']; })'; }
            };
        },

        // Prioritized choice
        choice: function(array) {
            var newArray = [];
            for (var i=0; i<array.length; i++) {
                if (array[i].type.charAt(0) !== '-')
                    newArray.push(array[i]);
            }
            
            return {
                type: 'Choice',
                elements: newArray,
                toCode: function (context) {
                    var es = [];
                    for (var i=0; i<this.elements.length; i++) {
                        es.push(this.elements[i].toCode(context));
                    }
                    return es.join('\n / ');
                },
                toString: function() { return this.elements.join('\n / '); } 
            };
        }, 

       // Null Object
        'null': function() {
            return {
                type: '-Null',
                toCode: function (context)  { return ''; },
                toString: function() { return ''; }
            };
        }
        
    };
    
    
    var jsMacroTypes = [

        // Repetition
        { type: 'Repetition',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              var elements = convertToPegObj(obj.elements);
              return pegObj2.repetition(elements, obj.punctuationMark);
          }          
        },

        // RepBlock [# ~ #] は 取り除く
        { type: 'RepBlock',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              var elements = convertToPegObj(obj.elements);
              return pegObj2.enclosing(this.type, elements);
          }
        },

        // Brace
        { type: 'Brace',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              var elements = convertToPegObj(obj.elements);
              return pegObj2.enclosing(this.type, elements);
          }
        },

        // Parentheses
        { type: 'Paren',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              var elements = convertToPegObj(obj.elements);
              return pegObj2.enclosing(this.type, elements);
          }
        },

        // Bracket
        { type: 'Bracket',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              var elements = convertToPegObj(obj.elements);
              return pegObj2.enclosing(this.type, elements);
          }
        },

        // IdentifierVariable
        { type: 'IdentifierVariable',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.identifier();
          }
        },

        // ExpressionVariable
        { type: 'ExpressionVariable',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.expression();
          }
        },

        // StatementVariable
        { type: 'StatementVariable',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.statement();
          }
        },

        // SymbolVariable
        { type: 'SymbolVariable',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.symbol();
          }
        },

        // LiteralKeyword
        { type: 'LiteralKeyword',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.keyword(obj.name);
          }
        },

        // Punctuator
        { type: 'Punctuator',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.punct(this.type, obj.value);
          }
        },

        // PunctuationMark
        { type: 'PunctuationMark',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.punct(this.type, obj.value);
          }
        },

        // BooleanLiteral
        { type: 'BooleanLiteral',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.literal(this.type, obj.value);
          }
        },

        // NumericLiteral
        { type: 'NumericLiteral',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.literal(this.type, obj.value);
          }
        },

        // StringLiteral
        { type: 'StringLiteral',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.literal(this.type, obj.value);
          }
        },

        // NullLiteral
        { type: 'NullLiteral',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.literal(this.type, null);
          }
        },
        
        // RegularExpressionLiteral
        { type: 'RegularExpressionLiteral',
          isType: function(t) { return t === this.type; },
          toPegObj: function(obj) {
              return pegObj2.literal(this.type, obj.value);
          }
        }
    ];

    var convertToPegObj = function(pattern) {

        if (pattern instanceof Array) {
            if (pattern.length === 0)
                return pegObj2.null();
            var result = [convertToPegObj(pattern[0])];
            for (var i=1; i<pattern.length; i++) {
                result.push(convertToPegObj(pattern[i]));
            }
            return pegObj2.sequence(result);
        } else if (pattern) {
            for (var i=0; i<jsMacroTypes.length; i++) {
                var type = jsMacroTypes[i];
                if (type.isType(pattern.type)) {
                    return type.toPegObj(pattern);
                }
            }
            return pegObj2.null();
        }
        return pegObj2.null();            
    };

    generator.generate = function(jsObj) {

        if (jsObj.type === 'Program') {
            var elements = jsObj.elements;
            var macroDefs = [];
            var expressionMacros = [];
            var statementMacros = [];
            for (var i=0; i<elements.length; i++) {
                var element = elements[i];
                if (element.type.indexOf('MacroDefinition') >= 0)
                    macroDefs.push(element);
            }

            for (var i=0; i<macroDefs.length; i++) {
                var macroDef = macroDefs[i];
                var macroName = pegObj2.macroName(macroDef.macroName);
                var syntaxRules = macroDef.syntaxRules;
                var patterns = [];
                for (var j=0; j<syntaxRules.length; j++) {
                    patterns.push(pegObj2.macroForm(macroName, syntaxRules[j].pattern));
                }
                patterns = pegObj2.choice(patterns);
                if (macroDef.type.indexOf('Expression') >= 0)
                    expressionMacros.push(patterns);
                else
                    statementMacros.push(patterns);
            }

            expressionMacros = expressionMacros.length > 0 ? pegObj2.choice(expressionMacros) : '';
            statementMacros = statementMacros.length > 0 ? pegObj2.choice(statementMacros) : '';

            return template + characterStatement
                + (expressionMacros?  macroExpression + expressionMacros.toCode('program') + '\n / ' + expressionMacros.toCode('template') + '\n\n' : '')
                + (statementMacros? macroStatement + statementMacros.toCode('program') + '\n / ' + statementMacros.toCode('template') + '\n\n' : '');
            
        } else {
            return 'error';
        }
    }

    return generator;
}());