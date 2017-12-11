const std = @import("std");
const builtin = @import("builtin");
const io = std.io;
const os = std.os;
const heap = std.heap;
const warn = std.debug.warn;
const assert = std.debug.assert;
const mem = std.mem;
const ArrayList = std.ArrayList;
const AlignedArrayList = std.AlignedArrayList;
const math = std.math;


const Token = struct {
    id: Id,
    start: usize,
    end: usize,

    const KeywordId = struct {
        bytes: []const u8,
        id: Id,
    };

    const keywords = []KeywordId {
        KeywordId{.bytes="align", .id = Id.Keyword_align},
        KeywordId{.bytes="and", .id = Id.Keyword_and},
        KeywordId{.bytes="asm", .id = Id.Keyword_asm},
        KeywordId{.bytes="break", .id = Id.Keyword_break},
        KeywordId{.bytes="coldcc", .id = Id.Keyword_coldcc},
        KeywordId{.bytes="comptime", .id = Id.Keyword_comptime},
        KeywordId{.bytes="const", .id = Id.Keyword_const},
        KeywordId{.bytes="continue", .id = Id.Keyword_continue},
        KeywordId{.bytes="defer", .id = Id.Keyword_defer},
        KeywordId{.bytes="else", .id = Id.Keyword_else},
        KeywordId{.bytes="enum", .id = Id.Keyword_enum},
        KeywordId{.bytes="error", .id = Id.Keyword_error},
        KeywordId{.bytes="export", .id = Id.Keyword_export},
        KeywordId{.bytes="extern", .id = Id.Keyword_extern},
        KeywordId{.bytes="false", .id = Id.Keyword_false},
        KeywordId{.bytes="fn", .id = Id.Keyword_fn},
        KeywordId{.bytes="for", .id = Id.Keyword_for},
        KeywordId{.bytes="goto", .id = Id.Keyword_goto},
        KeywordId{.bytes="if", .id = Id.Keyword_if},
        KeywordId{.bytes="inline", .id = Id.Keyword_inline},
        KeywordId{.bytes="nakedcc", .id = Id.Keyword_nakedcc},
        KeywordId{.bytes="noalias", .id = Id.Keyword_noalias},
        KeywordId{.bytes="null", .id = Id.Keyword_null},
        KeywordId{.bytes="or", .id = Id.Keyword_or},
        KeywordId{.bytes="packed", .id = Id.Keyword_packed},
        KeywordId{.bytes="pub", .id = Id.Keyword_pub},
        KeywordId{.bytes="return", .id = Id.Keyword_return},
        KeywordId{.bytes="stdcallcc", .id = Id.Keyword_stdcallcc},
        KeywordId{.bytes="struct", .id = Id.Keyword_struct},
        KeywordId{.bytes="switch", .id = Id.Keyword_switch},
        KeywordId{.bytes="test", .id = Id.Keyword_test},
        KeywordId{.bytes="this", .id = Id.Keyword_this},
        KeywordId{.bytes="true", .id = Id.Keyword_true},
        KeywordId{.bytes="undefined", .id = Id.Keyword_undefined},
        KeywordId{.bytes="union", .id = Id.Keyword_union},
        KeywordId{.bytes="unreachable", .id = Id.Keyword_unreachable},
        KeywordId{.bytes="use", .id = Id.Keyword_use},
        KeywordId{.bytes="var", .id = Id.Keyword_var},
        KeywordId{.bytes="volatile", .id = Id.Keyword_volatile},
        KeywordId{.bytes="while", .id = Id.Keyword_while},
    };

    fn getKeyword(bytes: []const u8) -> ?Id {
        for (keywords) |kw| {
            if (mem.eql(u8, kw.bytes, bytes)) {
                return kw.id;
            }
        }
        return null;
    }

    const StrLitKind = enum {Normal, C};

    const Id = union(enum) {
        Invalid,
        Identifier,
        StringLiteral: StrLitKind,
        Eof,
        Builtin,
        Equal,
        LParen,
        RParen,
        Semicolon,
        Percent,
        LBrace,
        RBrace,
        Period,
        Ellipsis2,
        Ellipsis3,
        Minus,
        Arrow,
        Colon,
        Slash,
        Comma,
        Ampersand,
        AmpersandEqual,
        NumberLiteral,
        Keyword_align,
        Keyword_and,
        Keyword_asm,
        Keyword_break,
        Keyword_coldcc,
        Keyword_comptime,
        Keyword_const,
        Keyword_continue,
        Keyword_defer,
        Keyword_else,
        Keyword_enum,
        Keyword_error,
        Keyword_export,
        Keyword_extern,
        Keyword_false,
        Keyword_fn,
        Keyword_for,
        Keyword_goto,
        Keyword_if,
        Keyword_inline,
        Keyword_nakedcc,
        Keyword_noalias,
        Keyword_null,
        Keyword_or,
        Keyword_packed,
        Keyword_pub,
        Keyword_return,
        Keyword_stdcallcc,
        Keyword_struct,
        Keyword_switch,
        Keyword_test,
        Keyword_this,
        Keyword_true,
        Keyword_undefined,
        Keyword_union,
        Keyword_unreachable,
        Keyword_use,
        Keyword_var,
        Keyword_volatile,
        Keyword_while,
    };
};

const Tokenizer = struct {
    buffer: []const u8,
    index: usize,

    pub const Location = struct {
        line: usize,
        column: usize,
        line_start: usize,
        line_end: usize,
    };

    pub fn getTokenLocation(self: &Tokenizer, token: &const Token) -> Location {
        var loc = Location {
            .line = 0,
            .column = 0,
            .line_start = 0,
            .line_end = 0,
        };
        for (self.buffer) |c, i| {
            if (i == token.start) {
                loc.line_end = i;
                while (loc.line_end < self.buffer.len and self.buffer[loc.line_end] != '\n') : (loc.line_end += 1) {}
                return loc;
            }
            if (c == '\n') {
                loc.line += 1;
                loc.column = 0;
                loc.line_start = i + 1;
            } else {
                loc.column += 1;
            }
        }
        return loc;
    }

    pub fn dump(self: &Tokenizer, token: &const Token) {
        warn("{} \"{}\"\n", @tagName(token.id), self.buffer[token.start..token.end]);
    }

    pub fn init(buffer: []const u8) -> Tokenizer {
        return Tokenizer {
            .buffer = buffer,
            .index = 0,
        };
    }

    const State = enum {
        Start,
        Identifier,
        Builtin,
        C,
        StringLiteral,
        StringLiteralBackslash,
        Minus,
        Slash,
        LineComment,
        Zero,
        NumberLiteral,
        NumberDot,
        FloatFraction,
        FloatExponentUnsigned,
        FloatExponentNumber,
        Ampersand,
        Period,
        Period2,
    };

    pub fn next(self: &Tokenizer) -> Token {
        var state = State.Start;
        var result = Token {
            .id = Token.Id.Eof,
            .start = self.index,
            .end = undefined,
        };
        while (self.index < self.buffer.len) : (self.index += 1) {
            const c = self.buffer[self.index];
            switch (state) {
                State.Start => switch (c) {
                    ' ', '\n' => {
                        result.start = self.index + 1;
                    },
                    'c' => {
                        state = State.C;
                        result.id = Token.Id.Identifier;
                    },
                    '"' => {
                        state = State.StringLiteral;
                        result.id = Token.Id { .StringLiteral = Token.StrLitKind.Normal };
                    },
                    'a'...'b', 'd'...'z', 'A'...'Z', '_' => {
                        state = State.Identifier;
                        result.id = Token.Id.Identifier;
                    },
                    '@' => {
                        state = State.Builtin;
                        result.id = Token.Id.Builtin;
                    },
                    '=' => {
                        result.id = Token.Id.Equal;
                        self.index += 1;
                        break;
                    },
                    '(' => {
                        result.id = Token.Id.LParen;
                        self.index += 1;
                        break;
                    },
                    ')' => {
                        result.id = Token.Id.RParen;
                        self.index += 1;
                        break;
                    },
                    ';' => {
                        result.id = Token.Id.Semicolon;
                        self.index += 1;
                        break;
                    },
                    ',' => {
                        result.id = Token.Id.Comma;
                        self.index += 1;
                        break;
                    },
                    ':' => {
                        result.id = Token.Id.Colon;
                        self.index += 1;
                        break;
                    },
                    '%' => {
                        result.id = Token.Id.Percent;
                        self.index += 1;
                        break;
                    },
                    '{' => {
                        result.id = Token.Id.LBrace;
                        self.index += 1;
                        break;
                    },
                    '}' => {
                        result.id = Token.Id.RBrace;
                        self.index += 1;
                        break;
                    },
                    '.' => {
                        state = State.Period;
                    },
                    '-' => {
                        state = State.Minus;
                    },
                    '/' => {
                        state = State.Slash;
                    },
                    '&' => {
                        state = State.Ampersand;
                    },
                    '0' => {
                        state = State.Zero;
                        result.id = Token.Id.NumberLiteral;
                    },
                    '1'...'9' => {
                        state = State.NumberLiteral;
                        result.id = Token.Id.NumberLiteral;
                    },
                    else => {
                        result.id = Token.Id.Invalid;
                        self.index += 1;
                        break;
                    },
                },
                State.Ampersand => switch (c) {
                    '=' => {
                        result.id = Token.Id.AmpersandEqual;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Ampersand;
                        break;
                    },
                },
                State.Identifier => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                    else => {
                        if (Token.getKeyword(self.buffer[result.start..self.index])) |id| {
                            result.id = id;
                        }
                        break;
                    },
                },
                State.Builtin => switch (c) {
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {},
                    else => break,
                },
                State.C => switch (c) {
                    '\\' => @panic("TODO"),
                    '"' => {
                        state = State.StringLiteral;
                        result.id = Token.Id { .StringLiteral = Token.StrLitKind.C };
                    },
                    'a'...'z', 'A'...'Z', '_', '0'...'9' => {
                        state = State.Identifier;
                    },
                    else => break,
                },
                State.StringLiteral => switch (c) {
                    '\\' => {
                        state = State.StringLiteralBackslash;
                    },
                    '"' => {
                        self.index += 1;
                        break;
                    },
                    '\n' => break, // Look for this error later.
                    else => {},
                },

                State.StringLiteralBackslash => switch (c) {
                    '\n' => break, // Look for this error later.
                    else => {
                        state = State.StringLiteral;
                    },
                },

                State.Minus => switch (c) {
                    '>' => {
                        result.id = Token.Id.Arrow;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Minus;
                        break;
                    },
                },

                State.Period => switch (c) {
                    '.' => {
                        state = State.Period2;
                    },
                    else => {
                        result.id = Token.Id.Period;
                        break;
                    },
                },

                State.Period2 => switch (c) {
                    '.' => {
                        result.id = Token.Id.Ellipsis3;
                        self.index += 1;
                        break;
                    },
                    else => {
                        result.id = Token.Id.Ellipsis2;
                        break;
                    },
                },

                State.Slash => switch (c) {
                    '/' => {
                        result.id = undefined;
                        state = State.LineComment;
                    },
                    else => {
                        result.id = Token.Id.Slash;
                        break;
                    },
                },
                State.LineComment => switch (c) {
                    '\n' => {
                        state = State.Start;
                        result = Token {
                            .id = Token.Id.Eof,
                            .start = self.index + 1,
                            .end = undefined,
                        };
                    },
                    else => {},
                },
                State.Zero => switch (c) {
                    'b', 'o', 'x' => {
                        state = State.NumberLiteral;
                    },
                    else => {
                        // reinterpret as a normal number
                        self.index -= 1;
                        state = State.NumberLiteral;
                    },
                },
                State.NumberLiteral => switch (c) {
                    '.' => {
                        state = State.NumberDot;
                    },
                    'p', 'P', 'e', 'E' => {
                        state = State.FloatExponentUnsigned;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => break,
                },
                State.NumberDot => switch (c) {
                    '.' => {
                        self.index -= 1;
                        state = State.Start;
                        break;
                    },
                    else => {
                        self.index -= 1;
                        state = State.FloatFraction;
                    },
                },
                State.FloatFraction => switch (c) {
                    'p', 'P', 'e', 'E' => {
                        state = State.FloatExponentUnsigned;
                    },
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => break,
                },
                State.FloatExponentUnsigned => switch (c) {
                    '+', '-' => {
                        state = State.FloatExponentNumber;
                    },
                    else => {
                        // reinterpret as a normal exponent number
                        self.index -= 1;
                        state = State.FloatExponentNumber;
                    }
                },
                State.FloatExponentNumber => switch (c) {
                    '0'...'9', 'a'...'f', 'A'...'F' => {},
                    else => break,
                },
            }
        }
        result.end = self.index;
        // TODO check state when returning EOF
        return result;
    }

    pub fn getTokenSlice(self: &const Tokenizer, token: &const Token) -> []const u8 {
        return self.buffer[token.start..token.end];
    }
};

const Comptime = enum { No, Yes };
const NoAlias = enum { No, Yes };
const Extern = enum { No, Yes };
const VarArgs = enum { No, Yes };
const Mutability = enum { Const, Var };
const Volatile = enum { No, Yes };

const Inline = enum {
    Auto,
    Always,
    Never,
};

const Visibility = enum {
    Private,
    Pub,
    Export,
};

const CallingConvention = enum {
    Auto,
    C,
    Cold,
    Naked,
    Stdcall,
};

const AstNode = struct {
    id: Id,

    const Id = enum {
        Root,
        VarDecl,
        Identifier,
        FnProto,
        ParamDecl,
        AddrOfExpr,
        Block,
    };

    fn iterate(base: &AstNode, index: usize) -> ?&AstNode {
        return switch (base.id) {
            Id.Root => @fieldParentPtr(AstNodeRoot, "base", base).iterate(index),
            Id.VarDecl => @fieldParentPtr(AstNodeVarDecl, "base", base).iterate(index),
            Id.Identifier => @fieldParentPtr(AstNodeIdentifier, "base", base).iterate(index),
            Id.FnProto => @fieldParentPtr(AstNodeFnProto, "base", base).iterate(index),
            Id.ParamDecl => @fieldParentPtr(AstNodeParamDecl, "base", base).iterate(index),
            Id.AddrOfExpr => @fieldParentPtr(AstNodeAddrOfExpr, "base", base).iterate(index),
            Id.Block => @fieldParentPtr(AstNodeBlock, "base", base).iterate(index),
        };
    }

    fn destroy(base: &AstNode, allocator: &mem.Allocator) {
        return switch (base.id) {
            Id.Root => allocator.destroy(@fieldParentPtr(AstNodeRoot, "base", base)),
            Id.VarDecl => allocator.destroy(@fieldParentPtr(AstNodeVarDecl, "base", base)),
            Id.Identifier => allocator.destroy(@fieldParentPtr(AstNodeIdentifier, "base", base)),
            Id.FnProto => allocator.destroy(@fieldParentPtr(AstNodeFnProto, "base", base)),
            Id.ParamDecl => allocator.destroy(@fieldParentPtr(AstNodeParamDecl, "base", base)),
            Id.AddrOfExpr => allocator.destroy(@fieldParentPtr(AstNodeAddrOfExpr, "base", base)),
            Id.Block => allocator.destroy(@fieldParentPtr(AstNodeBlock, "base", base)),
        };
    }
};

const AstNodeRoot = struct {
    base: AstNode,
    decls: ArrayList(&AstNode),

    fn iterate(self: &AstNodeRoot, index: usize) -> ?&AstNode {
        if (index < self.decls.len) {
            return self.decls.items[self.decls.len - index - 1];
        }
        return null;
    }
};

const AstNodeVarDecl = struct {
    base: AstNode,
    visib_token: ?Token,
    name_token: Token,
    eq_token: Token,
    mut_token: Token,
    comptime_token: ?Token,
    extern_token: ?Token,
    lib_name: ?&AstNode,
    type_node: ?&AstNode,
    align_node: ?&AstNode,
    init_node: ?&AstNode,

    fn iterate(self: &AstNodeVarDecl, index: usize) -> ?&AstNode {
        var i = index;

        if (self.type_node) |type_node| {
            if (i < 1) return type_node;
            i -= 1;
        }

        if (self.align_node) |align_node| {
            if (i < 1) return align_node;
            i -= 1;
        }

        if (self.init_node) |init_node| {
            if (i < 1) return init_node;
            i -= 1;
        }

        return null;
    }
};

const AstNodeIdentifier = struct {
    base: AstNode,
    name_token: Token,

    fn iterate(self: &AstNodeIdentifier, index: usize) -> ?&AstNode {
        return null;
    }
};

const AstNodeFnProto = struct {
    base: AstNode,
    visib_token: ?Token,
    fn_token: Token,
    name_token: ?Token,
    params: ArrayList(&AstNode),
    return_type: ?&AstNode,
    var_args_token: ?Token,
    extern_token: ?Token,
    inline_token: ?Token,
    cc_token: ?Token,
    body_node: ?&AstNode,
    lib_name: ?&AstNode, // populated if this is an extern declaration
    align_expr: ?&AstNode, // populated if align(A) is present

    fn iterate(self: &AstNodeFnProto, index: usize) -> ?&AstNode {
        var i = index;

        if (self.body_node) |body_node| {
            if (i < 1) return body_node;
            i -= 1;
        }

        if (self.return_type) |return_type| {
            if (i < 1) return return_type;
            i -= 1;
        }

        if (self.align_expr) |align_expr| {
            if (i < 1) return align_expr;
            i -= 1;
        }

        if (i < self.params.len) return self.params.items[self.params.len - i - 1];
        i -= self.params.len;

        if (self.lib_name) |lib_name| {
            if (i < 1) return lib_name;
            i -= 1;
        }

        return null;
    }
};

const AstNodeParamDecl = struct {
    base: AstNode,
    comptime_token: ?Token,
    noalias_token: ?Token,
    name_token: ?Token,
    type_node: &AstNode,
    var_args_token: ?Token,

    fn iterate(self: &AstNodeParamDecl, index: usize) -> ?&AstNode {
        var i = index;

        if (i < 1) return self.type_node;
        i -= 1;

        return null;
    }
};

const AstNodeAddrOfExpr = struct {
    base: AstNode,
    op_token: Token,
    align_expr: ?&AstNode,
    bit_offset_start_token: ?Token,
    bit_offset_end_token: ?Token,
    const_token: ?Token,
    volatile_token: ?Token,
    op_expr: &AstNode,

    fn iterate(self: &AstNodeAddrOfExpr, index: usize) -> ?&AstNode {
        var i = index;

        if (self.align_expr) |align_expr| {
            if (i < 1) return align_expr;
            i -= 1;
        }

        if (i < 1) return self.op_expr;
        i -= 1;

        return null;
    }
};

const AstNodeBlock = struct {
    base: AstNode,
    begin_token: Token,
    end_token: Token,
    statements: ArrayList(&AstNode),

    fn iterate(self: &AstNodeBlock, index: usize) -> ?&AstNode {
        var i = index;

        if (i < self.statements.len) return self.statements.items[i];
        i -= self.statements.len;

        return null;
    }
};

error ParseError;

const Parser = struct {
    allocator: &mem.Allocator,
    tokenizer: &Tokenizer,
    put_back_tokens: [2]Token,
    put_back_count: usize,
    source_file_name: []const u8,

    // This memory contents are used only during a function call. It's used to repurpose memory;
    // specifically so that freeAst can be guaranteed to succeed.
    const utility_bytes_align = @alignOf( union { a: RenderAstFrame, b: State, c: RenderState } );
    utility_bytes: []align(utility_bytes_align) u8,

    fn initUtilityArrayList(self: &Parser, comptime T: type) -> ArrayList(T) {
        const new_byte_count = self.utility_bytes.len - self.utility_bytes.len % @sizeOf(T);
        self.utility_bytes = self.allocator.alignedShrink(u8, utility_bytes_align, self.utility_bytes, new_byte_count);
        const typed_slice = ([]T)(self.utility_bytes);
        return ArrayList(T).fromOwnedSlice(self.allocator, typed_slice);
    }

    fn deinitUtilityArrayList(self: &Parser, list: var) {
        self.utility_bytes = ([]align(utility_bytes_align) u8)(list.toOwnedSlice());
    }

    pub fn init(tokenizer: &Tokenizer, allocator: &mem.Allocator, source_file_name: []const u8) -> Parser {
        return Parser {
            .allocator = allocator,
            .tokenizer = tokenizer,
            .put_back_tokens = undefined,
            .put_back_count = 0,
            .source_file_name = source_file_name,
            .utility_bytes = []align(utility_bytes_align) u8{},
        };
    }

    pub fn deinit(self: &Parser) {
        self.allocator.free(self.utility_bytes);
    }

    const TopLevelDeclCtx = struct {
        visib_token: ?Token,
        extern_token: ?Token,
    };

    const DestPtr = union(enum) {
        Field: &&AstNode,
        NullableField: &?&AstNode,
        List: &ArrayList(&AstNode),

        pub fn store(self: &const DestPtr, value: &AstNode) -> %void {
            switch (*self) {
                DestPtr.Field => |ptr| *ptr = value,
                DestPtr.NullableField => |ptr| *ptr = value,
                DestPtr.List => |list| %return list.append(value),
            }
        }
    };

    const State = union(enum) {
        TopLevel,
        TopLevelExtern: ?Token,
        TopLevelDecl: TopLevelDeclCtx,
        Expression: DestPtr,
        GroupedExpression: DestPtr,
        UnwrapExpression: DestPtr,
        BoolOrExpression: DestPtr,
        BoolAndExpression: DestPtr,
        ComparisonExpression: DestPtr,
        BinaryOrExpression: DestPtr,
        BinaryXorExpression: DestPtr,
        BinaryAndExpression: DestPtr,
        BitShiftExpression: DestPtr,
        AdditionExpression: DestPtr,
        MultiplyExpression: DestPtr,
        BraceSuffixExpression: DestPtr,
        PrefixOpExpression: DestPtr,
        SuffixOpExpression: DestPtr,
        PrimaryExpression: DestPtr,
        TypeExpr: DestPtr,
        VarDecl: &AstNodeVarDecl,
        VarDeclAlign: &AstNodeVarDecl,
        VarDeclEq: &AstNodeVarDecl,
        ExpectToken: @TagType(Token.Id),
        FnProto: &AstNodeFnProto,
        FnProtoAlign: &AstNodeFnProto,
        ParamDecl: &AstNodeFnProto,
        ParamDeclComma,
        FnDef: &AstNodeFnProto,
        Block: &AstNodeBlock,
        Statement: &AstNodeBlock,
    };

    pub fn freeAst(self: &Parser, root_node: &AstNodeRoot) {
        // utility_bytes is big enough to do this iteration since we were able to do
        // the parsing in the first place
        comptime assert(@sizeOf(State) >= @sizeOf(&AstNode));

        var stack = self.initUtilityArrayList(&AstNode);
        defer self.deinitUtilityArrayList(stack);

        stack.append(&root_node.base) %% unreachable;
        while (stack.popOrNull()) |node| {
            var i: usize = 0;
            while (node.iterate(i)) |child| : (i += 1) {
                if (child.iterate(0) != null) {
                    stack.append(child) %% unreachable;
                } else {
                    child.destroy(self.allocator);
                }
            }
            node.destroy(self.allocator);
        }
    }

    pub fn parse(self: &Parser) -> %&AstNodeRoot {
        var stack = self.initUtilityArrayList(State);
        defer self.deinitUtilityArrayList(stack);

        const root_node = %return self.createRoot();
        %defer self.allocator.destroy(root_node);
        %return stack.append(State.TopLevel);
        %defer self.freeAst(root_node);

        while (true) {
            //{
            //    const token = self.getNextToken();
            //    warn("{} ", @tagName(token.id));
            //    self.putBackToken(token);
            //    var i: usize = stack.len;
            //    while (i != 0) {
            //        i -= 1;
            //        warn("{} ", @tagName(stack.items[i]));
            //    }
            //    warn("\n");
            //}

            // This gives us 1 free append that can't fail
            const state = stack.pop();

            switch (state) {
                State.TopLevel => {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_pub, Token.Id.Keyword_export => {
                            stack.append(State { .TopLevelExtern = token }) %% unreachable;
                            continue;
                        },
                        Token.Id.Eof => return root_node,
                        else => {
                            self.putBackToken(token);
                            // TODO shouldn't need this cast
                            stack.append(State { .TopLevelExtern = null }) %% unreachable;
                            continue;
                        },
                    }
                },
                State.TopLevelExtern => |visib_token| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Keyword_extern) {
                        stack.append(State {
                            .TopLevelDecl = TopLevelDeclCtx {
                                .visib_token = visib_token,
                                .extern_token = token,
                            },
                        }) %% unreachable;
                        continue;
                    }
                    self.putBackToken(token);
                    stack.append(State {
                        .TopLevelDecl = TopLevelDeclCtx {
                            .visib_token = visib_token,
                            .extern_token = null,
                        },
                    }) %% unreachable;
                    continue;
                },
                State.TopLevelDecl => |ctx| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Keyword_var, Token.Id.Keyword_const => {
                            stack.append(State.TopLevel) %% unreachable;
                            // TODO shouldn't need these casts
                            const var_decl_node = %return self.createAttachVarDecl(&root_node.decls, ctx.visib_token,
                                token, (?Token)(null), ctx.extern_token);
                            %return stack.append(State { .VarDecl = var_decl_node });
                            continue;
                        },
                        Token.Id.Keyword_fn => {
                            stack.append(State.TopLevel) %% unreachable;
                            // TODO shouldn't need these casts
                            const fn_proto = %return self.createAttachFnProto(&root_node.decls, token,
                                ctx.extern_token, (?Token)(null), (?Token)(null), (?Token)(null));
                            %return stack.append(State { .FnDef = fn_proto });
                            %return stack.append(State { .FnProto = fn_proto });
                            continue;
                        },
                        Token.Id.StringLiteral => {
                            @panic("TODO extern with string literal");
                        },
                        Token.Id.Keyword_coldcc, Token.Id.Keyword_nakedcc, Token.Id.Keyword_stdcallcc => {
                            stack.append(State.TopLevel) %% unreachable;
                            const fn_token = %return self.eatToken(Token.Id.Keyword_fn);
                            // TODO shouldn't need this cast
                            const fn_proto = %return self.createAttachFnProto(&root_node.decls, fn_token,
                                ctx.extern_token, (?Token)(token), (?Token)(null), (?Token)(null));
                            %return stack.append(State { .FnDef = fn_proto });
                            %return stack.append(State { .FnProto = fn_proto });
                            continue;
                        },
                        else => return self.parseError(token, "expected variable declaration or function, found {}", @tagName(token.id)),
                    }
                },
                State.VarDecl => |var_decl| {
                    var_decl.name_token = %return self.eatToken(Token.Id.Identifier);
                    stack.append(State { .VarDeclAlign = var_decl }) %% unreachable;

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Colon) {
                        %return stack.append(State { .TypeExpr = DestPtr {.NullableField = &var_decl.type_node} });
                        continue;
                    }

                    self.putBackToken(next_token);
                    continue;
                },
                State.VarDeclAlign => |var_decl| {
                    stack.append(State { .VarDeclEq = var_decl }) %% unreachable;

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Keyword_align) {
                        %return stack.append(State {
                            .GroupedExpression = DestPtr {
                                .NullableField = &var_decl.align_node
                            }
                        });
                        continue;
                    }

                    self.putBackToken(next_token);
                    continue;
                },
                State.VarDeclEq => |var_decl| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Equal) {
                        var_decl.eq_token = token;
                        stack.append(State { .ExpectToken = Token.Id.Semicolon }) %% unreachable;
                        %return stack.append(State {
                            .Expression = DestPtr {.NullableField = &var_decl.init_node},
                        });
                        continue;
                    }
                    if (token.id == Token.Id.Semicolon) {
                        continue;
                    }
                    return self.parseError(token, "expected '=' or ';', found {}", @tagName(token.id));
                },
                State.ExpectToken => |token_id| {
                    _ = %return self.eatToken(token_id);
                    continue;
                },
                State.Expression => |dest_ptr| {
                    stack.append(State {.UnwrapExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.UnwrapExpression => |dest_ptr| {
                    stack.append(State {.BoolOrExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BoolOrExpression => |dest_ptr| {
                    stack.append(State {.BoolAndExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BoolAndExpression => |dest_ptr| {
                    stack.append(State {.ComparisonExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.ComparisonExpression => |dest_ptr| {
                    stack.append(State {.BinaryOrExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BinaryOrExpression => |dest_ptr| {
                    stack.append(State {.BinaryXorExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BinaryXorExpression => |dest_ptr| {
                    stack.append(State {.BinaryAndExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BinaryAndExpression => |dest_ptr| {
                    stack.append(State {.BitShiftExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BitShiftExpression => |dest_ptr| {
                    stack.append(State {.AdditionExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.AdditionExpression => |dest_ptr| {
                    stack.append(State {.MultiplyExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.MultiplyExpression => |dest_ptr| {
                    stack.append(State {.BraceSuffixExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.BraceSuffixExpression => |dest_ptr| {
                    stack.append(State {.PrefixOpExpression = dest_ptr}) %% unreachable;
                    continue;
                },

                State.PrefixOpExpression => |dest_ptr| {
                    const first_token = self.getNextToken();
                    if (first_token.id == Token.Id.Ampersand) {
                        const addr_of_expr = %return self.createAttachAddrOfExpr(dest_ptr, first_token);
                        var token = self.getNextToken();
                        if (token.id == Token.Id.Keyword_align) {
                            @panic("TODO align");
                        }
                        if (token.id == Token.Id.Keyword_const) {
                            addr_of_expr.const_token = token;
                            token = self.getNextToken();
                        }
                        if (token.id == Token.Id.Keyword_volatile) {
                            addr_of_expr.volatile_token = token;
                            token = self.getNextToken();
                        }
                        self.putBackToken(token);
                        stack.append(State {
                            .PrefixOpExpression = DestPtr { .Field = &addr_of_expr.op_expr},
                        }) %% unreachable;
                        continue;
                    }

                    self.putBackToken(first_token);
                    stack.append(State { .SuffixOpExpression = dest_ptr }) %% unreachable;
                    continue;
                },

                State.SuffixOpExpression => |dest_ptr| {
                    stack.append(State { .PrimaryExpression = dest_ptr }) %% unreachable;
                    continue;
                },

                State.PrimaryExpression => |dest_ptr| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.Identifier => {
                            const identifier = %return self.createIdentifier(token);
                            %return dest_ptr.store(&identifier.base);
                            continue;
                        },
                        else => return self.parseError(token, "expected primary expression, found {}", @tagName(token.id)),
                    }
                },

                State.TypeExpr => |dest_ptr| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Keyword_var) {
                        @panic("TODO param with type var");
                    }
                    self.putBackToken(token);

                    stack.append(State { .PrefixOpExpression = dest_ptr }) %% unreachable;
                    continue;
                },

                State.FnProto => |fn_proto| {
                    stack.append(State { .FnProtoAlign = fn_proto }) %% unreachable;
                    %return stack.append(State { .ParamDecl = fn_proto });
                    %return stack.append(State { .ExpectToken = Token.Id.LParen });

                    const next_token = self.getNextToken();
                    if (next_token.id == Token.Id.Identifier) {
                        fn_proto.name_token = next_token;
                        continue;
                    }
                    self.putBackToken(next_token);
                    continue;
                },

                State.FnProtoAlign => |fn_proto| {
                    const token = self.getNextToken();
                    if (token.id == Token.Id.Keyword_align) {
                        @panic("TODO fn proto align");
                    }
                    if (token.id == Token.Id.Arrow) {
                        stack.append(State {
                            .TypeExpr = DestPtr {.NullableField = &fn_proto.return_type},
                        }) %% unreachable;
                        continue;
                    } else {
                        self.putBackToken(token);
                        continue;
                    }
                },

                State.ParamDecl => |fn_proto| {
                    var token = self.getNextToken();
                    if (token.id == Token.Id.RParen) {
                        continue;
                    }
                    const param_decl = %return self.createAttachParamDecl(&fn_proto.params);
                    if (token.id == Token.Id.Keyword_comptime) {
                        param_decl.comptime_token = token;
                        token = self.getNextToken();
                    } else if (token.id == Token.Id.Keyword_noalias) {
                        param_decl.noalias_token = token;
                        token = self.getNextToken();
                    };
                    if (token.id == Token.Id.Identifier) {
                        const next_token = self.getNextToken();
                        if (next_token.id == Token.Id.Colon) {
                            param_decl.name_token = token;
                            token = self.getNextToken();
                        } else {
                            self.putBackToken(next_token);
                        }
                    }
                    if (token.id == Token.Id.Ellipsis3) {
                        param_decl.var_args_token = token;
                        stack.append(State { .ExpectToken = Token.Id.RParen }) %% unreachable;
                        continue;
                    } else {
                        self.putBackToken(token);
                    }

                    stack.append(State { .ParamDecl = fn_proto }) %% unreachable;
                    %return stack.append(State.ParamDeclComma);
                    %return stack.append(State {
                        .TypeExpr = DestPtr {.Field = &param_decl.type_node}
                    });
                    continue;
                },

                State.ParamDeclComma => {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.RParen => {
                            _ = stack.pop(); // pop off the ParamDecl
                            continue;
                        },
                        Token.Id.Comma => continue,
                        else => return self.parseError(token, "expected ',' or ')', found {}", @tagName(token.id)),
                    }
                },

                State.FnDef => |fn_proto| {
                    const token = self.getNextToken();
                    switch(token.id) {
                        Token.Id.LBrace => {
                            const block = %return self.createBlock(token);
                            fn_proto.body_node = &block.base;
                            stack.append(State { .Block = block }) %% unreachable;
                            continue;
                        },
                        Token.Id.Semicolon => continue,
                        else => return self.parseError(token, "expected ';' or '{{', found {}", @tagName(token.id)),
                    }
                },

                State.Block => |block| {
                    const token = self.getNextToken();
                    switch (token.id) {
                        Token.Id.RBrace => {
                            block.end_token = token;
                            continue;
                        },
                        else => {
                            self.putBackToken(token);
                            stack.append(State { .Block = block }) %% unreachable;
                            %return stack.append(State { .Statement = block });
                            continue;
                        },
                    }
                },

                State.Statement => |block| {
                    {
                        // Look for comptime var, comptime const
                        const comptime_token = self.getNextToken();
                        if (comptime_token.id == Token.Id.Keyword_comptime) {
                            const mut_token = self.getNextToken();
                            if (mut_token.id == Token.Id.Keyword_var or mut_token.id == Token.Id.Keyword_const) {
                                // TODO shouldn't need these casts
                                const var_decl = %return self.createAttachVarDecl(&block.statements, (?Token)(null),
                                    mut_token, (?Token)(comptime_token), (?Token)(null));
                                %return stack.append(State { .VarDecl = var_decl });
                                continue;
                            }
                            self.putBackToken(mut_token);
                        }
                        self.putBackToken(comptime_token);
                    }
                    {
                        // Look for const, var
                        const mut_token = self.getNextToken();
                        if (mut_token.id == Token.Id.Keyword_var or mut_token.id == Token.Id.Keyword_const) {
                            // TODO shouldn't need these casts
                            const var_decl = %return self.createAttachVarDecl(&block.statements, (?Token)(null),
                                mut_token, (?Token)(null), (?Token)(null));
                            %return stack.append(State { .VarDecl = var_decl });
                            continue;
                        }
                        self.putBackToken(mut_token);
                    }

                    stack.append(State { .ExpectToken = Token.Id.Semicolon }) %% unreachable;
                    %return stack.append(State { .Expression = DestPtr{.List = &block.statements} });
                    continue;
                },

                State.GroupedExpression => @panic("TODO"),
            }
            unreachable;
        }
    }

    fn createRoot(self: &Parser) -> %&AstNodeRoot {
        const node = %return self.allocator.create(AstNodeRoot);
        %defer self.allocator.destroy(node);

        *node = AstNodeRoot {
            .base = AstNode {.id = AstNode.Id.Root},
            .decls = ArrayList(&AstNode).init(self.allocator),
        };
        return node;
    }

    fn createVarDecl(self: &Parser, visib_token: &const ?Token, mut_token: &const Token, comptime_token: &const ?Token,
        extern_token: &const ?Token) -> %&AstNodeVarDecl
    {
        const node = %return self.allocator.create(AstNodeVarDecl);
        %defer self.allocator.destroy(node);

        *node = AstNodeVarDecl {
            .base = AstNode {.id = AstNode.Id.VarDecl},
            .visib_token = *visib_token,
            .mut_token = *mut_token,
            .comptime_token = *comptime_token,
            .extern_token = *extern_token,
            .type_node = null,
            .align_node = null,
            .init_node = null,
            .lib_name = null,
            // initialized later
            .name_token = undefined,
            .eq_token = undefined,
        };
        return node;
    }

    fn createIdentifier(self: &Parser, name_token: &const Token) -> %&AstNodeIdentifier {
        const node = %return self.allocator.create(AstNodeIdentifier);
        %defer self.allocator.destroy(node);

        *node = AstNodeIdentifier {
            .base = AstNode {.id = AstNode.Id.Identifier},
            .name_token = *name_token,
        };
        return node;
    }

    fn createFnProto(self: &Parser, fn_token: &const Token, extern_token: &const ?Token,
        cc_token: &const ?Token, visib_token: &const ?Token, inline_token: &const ?Token) -> %&AstNodeFnProto
    {
        const node = %return self.allocator.create(AstNodeFnProto);
        %defer self.allocator.destroy(node);

        *node = AstNodeFnProto {
            .base = AstNode {.id = AstNode.Id.FnProto},
            .visib_token = *visib_token,
            .name_token = null,
            .fn_token = *fn_token,
            .params = ArrayList(&AstNode).init(self.allocator),
            .return_type = null,
            .var_args_token = null,
            .extern_token = *extern_token,
            .inline_token = *inline_token,
            .cc_token = *cc_token,
            .body_node = null,
            .lib_name = null,
            .align_expr = null,
        };
        return node;
    }

    fn createParamDecl(self: &Parser) -> %&AstNodeParamDecl {
        const node = %return self.allocator.create(AstNodeParamDecl);
        %defer self.allocator.destroy(node);

        *node = AstNodeParamDecl {
            .base = AstNode {.id = AstNode.Id.ParamDecl},
            .comptime_token = null,
            .noalias_token = null,
            .name_token = null,
            .type_node = undefined,
            .var_args_token = null,
        };
        return node;
    }

    fn createAddrOfExpr(self: &Parser, op_token: &const Token) -> %&AstNodeAddrOfExpr {
        const node = %return self.allocator.create(AstNodeAddrOfExpr);
        %defer self.allocator.destroy(node);

        *node = AstNodeAddrOfExpr {
            .base = AstNode {.id = AstNode.Id.AddrOfExpr},
            .align_expr = null,
            .op_token = *op_token,
            .bit_offset_start_token = null,
            .bit_offset_end_token = null,
            .const_token = null,
            .volatile_token = null,
            .op_expr = undefined,
        };
        return node;
    }

    fn createBlock(self: &Parser, begin_token: &const Token) -> %&AstNodeBlock {
        const node = %return self.allocator.create(AstNodeBlock);
        %defer self.allocator.destroy(node);

        *node = AstNodeBlock {
            .base = AstNode {.id = AstNode.Id.Block},
            .begin_token = *begin_token,
            .end_token = undefined,
            .statements = ArrayList(&AstNode).init(self.allocator),
        };
        return node;
    }

    fn createAttachAddrOfExpr(self: &Parser, dest_ptr: &const DestPtr, op_token: &const Token) -> %&AstNodeAddrOfExpr {
        const node = %return self.createAddrOfExpr(op_token);
        %defer self.allocator.destroy(node);
        %return dest_ptr.store(&node.base);
        return node;
    }

    fn createAttachParamDecl(self: &Parser, list: &ArrayList(&AstNode)) -> %&AstNodeParamDecl {
        const node = %return self.createParamDecl();
        %defer self.allocator.destroy(node);
        %return list.append(&node.base);
        return node;
    }

    fn createAttachFnProto(self: &Parser, list: &ArrayList(&AstNode), fn_token: &const Token,
        extern_token: &const ?Token, cc_token: &const ?Token, visib_token: &const ?Token,
        inline_token: &const ?Token) -> %&AstNodeFnProto
    {
        const node = %return self.createFnProto(fn_token, extern_token, cc_token, visib_token, inline_token);
        %defer self.allocator.destroy(node);
        %return list.append(&node.base);
        return node;
    }

    fn createAttachVarDecl(self: &Parser, list: &ArrayList(&AstNode), visib_token: &const ?Token,
        mut_token: &const Token, comptime_token: &const ?Token, extern_token: &const ?Token) -> %&AstNodeVarDecl
    {
        const node = %return self.createVarDecl(visib_token, mut_token, comptime_token, extern_token);
        %defer self.allocator.destroy(node);
        %return list.append(&node.base);
        return node;
    }

    fn parseError(self: &Parser, token: &const Token, comptime fmt: []const u8, args: ...) -> error {
        const loc = self.tokenizer.getTokenLocation(token);
        warn("{}:{}:{}: error: " ++ fmt ++ "\n", self.source_file_name, loc.line + 1, loc.column + 1, args);
        warn("{}\n", self.tokenizer.buffer[loc.line_start..loc.line_end]);
        {
            var i: usize = 0;
            while (i < loc.column) : (i += 1) {
                warn(" ");
            }
        }
        {
            const caret_count = token.end - token.start;
            var i: usize = 0;
            while (i < caret_count) : (i += 1) {
                warn("~");
            }
        }
        warn("\n");
        return error.ParseError;
    }

    fn expectToken(self: &Parser, token: &const Token, id: @TagType(Token.Id)) -> %void {
        if (token.id != id) {
            return self.parseError(token, "expected {}, found {}", @tagName(id), @tagName(token.id));
        }
    }

    fn eatToken(self: &Parser, id: @TagType(Token.Id)) -> %Token {
        const token = self.getNextToken();
        %return self.expectToken(token, id);
        return token;
    }

    fn putBackToken(self: &Parser, token: &const Token) {
        self.put_back_tokens[self.put_back_count] = *token;
        self.put_back_count += 1;
    }

    fn getNextToken(self: &Parser) -> Token {
        return if (self.put_back_count != 0) {
            const put_back_index = self.put_back_count - 1;
            const put_back_token = self.put_back_tokens[put_back_index];
            self.put_back_count = put_back_index;
            put_back_token
        } else {
            self.tokenizer.next()
        };
    }

    const RenderAstFrame = struct {
        node: &AstNode,
        indent: usize,
    };

    pub fn renderAst(self: &Parser, stream: &std.io.OutStream, root_node: &AstNodeRoot) -> %void {
        var stack = self.initUtilityArrayList(RenderAstFrame);
        defer self.deinitUtilityArrayList(stack);

        %return stack.append(RenderAstFrame {
            .node = &root_node.base,
            .indent = 0,
        });

        while (stack.popOrNull()) |frame| {
            {
                var i: usize = 0;
                while (i < frame.indent) : (i += 1) {
                    %return stream.print(" ");
                }
            }
            %return stream.print("{}\n", @tagName(frame.node.id));
            var child_i: usize = 0;
            while (frame.node.iterate(child_i)) |child| : (child_i += 1) {
                %return stack.append(RenderAstFrame {
                    .node = child,
                    .indent = frame.indent + 2,
                });
            }
        }
    }


    pub const RenderState = union(enum) {
        TopLevelDecl: &AstNode,
        FnProtoRParen: &AstNodeFnProto,
        ParamDecl: &AstNode,
        Text: []const u8,
        Expression: &AstNode,
        AddrOfExprBit: &AstNodeAddrOfExpr,
        VarDecl: &AstNodeVarDecl,
        VarDeclAlign: &AstNodeVarDecl,
        Statement: &AstNode,
        PrintIndent,
        Indent: usize,
    };

    pub fn renderSource(self: &Parser, stream: &std.io.OutStream, root_node: &AstNodeRoot) -> %void {
        var stack = self.initUtilityArrayList(RenderState);
        defer self.deinitUtilityArrayList(stack);

        {
            var i = root_node.decls.len;
            while (i != 0) {
                i -= 1;
                const decl = root_node.decls.items[i];
                %return stack.append(RenderState {.TopLevelDecl = decl});
            }
        }

        const indent_delta = 4;
        var indent: usize = 0;
        while (stack.popOrNull()) |state| {
            switch (state) {
                RenderState.TopLevelDecl => |decl| {
                    switch (decl.id) {
                        AstNode.Id.FnProto => {
                            const fn_proto = @fieldParentPtr(AstNodeFnProto, "base", decl);
                            if (fn_proto.visib_token) |visib_token| {
                                switch (visib_token.id) {
                                    Token.Id.Keyword_pub => %return stream.print("pub "),
                                    Token.Id.Keyword_export => %return stream.print("export "),
                                    else => unreachable,
                                };
                            }
                            if (fn_proto.extern_token) |extern_token| {
                                %return stream.print("{} ", self.tokenizer.getTokenSlice(extern_token));
                            }
                            %return stream.print("fn");

                            if (fn_proto.name_token) |name_token| {
                                %return stream.print(" {}", self.tokenizer.getTokenSlice(name_token));
                            }

                            %return stream.print("(");

                            %return stack.append(RenderState { .Text = "\n" });
                            if (fn_proto.body_node == null) {
                                %return stack.append(RenderState { .Text = ";" });
                            }

                            %return stack.append(RenderState { .FnProtoRParen = fn_proto});
                            var i = fn_proto.params.len;
                            while (i != 0) {
                                i -= 1;
                                const param_decl_node = fn_proto.params.items[i];
                                %return stack.append(RenderState { .ParamDecl = param_decl_node});
                                if (i != 0) {
                                    %return stack.append(RenderState { .Text = ", " });
                                }
                            }
                        },
                        AstNode.Id.VarDecl => {
                            const var_decl = @fieldParentPtr(AstNodeVarDecl, "base", decl);
                            %return stack.append(RenderState { .Text = "\n"});
                            %return stack.append(RenderState { .VarDecl = var_decl});

                        },
                        else => unreachable,
                    }
                },

                RenderState.VarDecl => |var_decl| {
                    if (var_decl.visib_token) |visib_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(visib_token));
                    }
                    if (var_decl.extern_token) |extern_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(extern_token));
                        if (var_decl.lib_name != null) {
                            @panic("TODO");
                        }
                    }
                    if (var_decl.comptime_token) |comptime_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(comptime_token));
                    }
                    %return stream.print("{} ", self.tokenizer.getTokenSlice(var_decl.mut_token));
                    %return stream.print("{}", self.tokenizer.getTokenSlice(var_decl.name_token));

                    %return stack.append(RenderState { .VarDeclAlign = var_decl });
                    if (var_decl.type_node) |type_node| {
                        %return stream.print(": ");
                        %return stack.append(RenderState { .Expression = type_node });
                    }
                },

                RenderState.VarDeclAlign => |var_decl| {
                    if (var_decl.align_node != null) {
                        @panic("TODO");
                    }
                    %return stack.append(RenderState { .Text = ";" });
                    if (var_decl.init_node) |init_node| {
                        %return stream.print(" = ");
                        %return stack.append(RenderState { .Expression = init_node });
                    }
                },

                RenderState.ParamDecl => |base| {
                    const param_decl = @fieldParentPtr(AstNodeParamDecl, "base", base);
                    if (param_decl.comptime_token) |comptime_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(comptime_token));
                    }
                    if (param_decl.noalias_token) |noalias_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(noalias_token));
                    }
                    if (param_decl.name_token) |name_token| {
                        %return stream.print("{}: ", self.tokenizer.getTokenSlice(name_token));
                    }
                    if (param_decl.var_args_token) |var_args_token| {
                        %return stream.print("{}", self.tokenizer.getTokenSlice(var_args_token));
                    } else {
                        %return stack.append(RenderState { .Expression = param_decl.type_node});
                    }
                },
                RenderState.Text => |bytes| {
                    %return stream.write(bytes);
                },
                RenderState.Expression => |base| switch (base.id) {
                    AstNode.Id.Identifier => {
                        const identifier = @fieldParentPtr(AstNodeIdentifier, "base", base);
                        %return stream.print("{}", self.tokenizer.getTokenSlice(identifier.name_token));
                    },
                    AstNode.Id.AddrOfExpr => {
                        const addr_of_expr = @fieldParentPtr(AstNodeAddrOfExpr, "base", base);
                        %return stream.print("{}", self.tokenizer.getTokenSlice(addr_of_expr.op_token));
                        %return stack.append(RenderState { .AddrOfExprBit = addr_of_expr});

                        if (addr_of_expr.align_expr) |align_expr| {
                            %return stream.print("align(");
                            %return stack.append(RenderState { .Text = ")"});
                            %return stack.append(RenderState { .Expression = align_expr});
                        }
                    },
                    AstNode.Id.Block => {
                        const block = @fieldParentPtr(AstNodeBlock, "base", base);
                        %return stream.write("{");
                        %return stack.append(RenderState { .Text = "}"});
                        %return stack.append(RenderState.PrintIndent);
                        %return stack.append(RenderState { .Indent = indent});
                        %return stack.append(RenderState { .Text = "\n"});
                        var i = block.statements.len;
                        while (i != 0) {
                            i -= 1;
                            const statement_node = block.statements.items[i];
                            %return stack.append(RenderState { .Statement = statement_node});
                            %return stack.append(RenderState.PrintIndent);
                            %return stack.append(RenderState { .Indent = indent + indent_delta});
                            %return stack.append(RenderState { .Text = "\n" });
                        }
                    },
                    else => unreachable,
                },
                RenderState.AddrOfExprBit => |addr_of_expr| {
                    if (addr_of_expr.bit_offset_start_token) |bit_offset_start_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(bit_offset_start_token));
                    }
                    if (addr_of_expr.bit_offset_end_token) |bit_offset_end_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(bit_offset_end_token));
                    }
                    if (addr_of_expr.const_token) |const_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(const_token));
                    }
                    if (addr_of_expr.volatile_token) |volatile_token| {
                        %return stream.print("{} ", self.tokenizer.getTokenSlice(volatile_token));
                    }
                    %return stack.append(RenderState { .Expression = addr_of_expr.op_expr});
                },
                RenderState.FnProtoRParen => |fn_proto| {
                    %return stream.print(")");
                    if (fn_proto.align_expr != null) {
                        @panic("TODO");
                    }
                    if (fn_proto.return_type) |return_type| {
                        %return stream.print(" -> ");
                        if (fn_proto.body_node) |body_node| {
                            %return stack.append(RenderState { .Expression = body_node});
                            %return stack.append(RenderState { .Text = " "});
                        }
                        %return stack.append(RenderState { .Expression = return_type});
                    }
                },
                RenderState.Statement => |base| {
                    switch (base.id) {
                        AstNode.Id.VarDecl => {
                            const var_decl = @fieldParentPtr(AstNodeVarDecl, "base", base);
                            %return stack.append(RenderState { .VarDecl = var_decl});
                        },
                        else => unreachable,
                    }
                },
                RenderState.Indent => |new_indent| indent = new_indent,
                RenderState.PrintIndent => %return stream.writeByteNTimes(' ', indent),
            }
        }
    }
};

pub fn main() -> %void {
    main2() %% |err| {
        warn("{}\n", @errorName(err));
        return err;
    };
}

pub fn main2() -> %void {
    var incrementing_allocator = %return heap.IncrementingAllocator.init(10 * 1024 * 1024);
    defer incrementing_allocator.deinit();

    const allocator = &incrementing_allocator.allocator;

    const args = %return os.argsAlloc(allocator);
    defer os.argsFree(allocator, args);

    const target_file = args[1];

    const target_file_buf = %return io.readFileAlloc(target_file, allocator);
    defer allocator.free(target_file_buf);

    var stderr_file = %return std.io.getStdErr();
    var stderr_file_out_stream = std.io.FileOutStream.init(&stderr_file);
    const out_stream = &stderr_file_out_stream.stream;

    warn("====input:====\n");

    warn("{}", target_file_buf);

    warn("====tokenization:====\n");
    {
        var tokenizer = Tokenizer.init(target_file_buf);
        while (true) {
            const token = tokenizer.next();
            tokenizer.dump(token);
            if (token.id == Token.Id.Eof) {
                break;
            }
        }
    }

    warn("====parse:====\n");

    var tokenizer = Tokenizer.init(target_file_buf);
    var parser = Parser.init(&tokenizer, allocator, target_file);
    defer parser.deinit();

    const root_node = %return parser.parse();
    defer parser.freeAst(root_node);

    %return parser.renderAst(out_stream, root_node);

    warn("====fmt:====\n");
    %return parser.renderSource(out_stream, root_node);
}


fn testCanonical(source: []const u8) {
    const allocator = std.debug.global_allocator;
    std.debug.global_allocator_index = 0;

    var tokenizer = Tokenizer.init(source);
    var parser = Parser.init(&tokenizer, allocator, "(memory buffer)");
    defer parser.deinit();

    const root_node = parser.parse() %% unreachable;
    defer parser.freeAst(root_node);

    var buffer = std.Buffer.initSize(allocator, 0) %% unreachable;
    var buffer_out_stream = io.BufferOutStream.init(&buffer);
    parser.renderSource(&buffer_out_stream.stream, root_node) %% unreachable;

    if (!mem.eql(u8, buffer.toSliceConst(), source)) {
        warn("\n====== expected this output: =========\n");
        warn("{}", source);
        warn("\n======== instead found this: =========\n");
        warn("{}", buffer.toSliceConst());
        warn("\n======================================\n");
        @panic("test failed");
    }
}

test "zig fmt" {
    if (builtin.os == builtin.Os.windows and builtin.arch == builtin.Arch.i386) {
        // TODO get this test passing
        // https://github.com/zig-lang/zig/issues/537
        return;
    }

    testCanonical(
        \\extern fn puts(s: &const u8) -> c_int;
        \\
    );

    testCanonical(
        \\const a = b;
        \\pub const a = b;
        \\var a = b;
        \\pub var a = b;
        \\const a: i32 = b;
        \\pub const a: i32 = b;
        \\var a: i32 = b;
        \\pub var a: i32 = b;
        \\
    );

    testCanonical(
        \\extern var foo: c_int;
        \\
    );

    testCanonical(
        \\fn main(argc: c_int, argv: &&u8) -> c_int {
        \\    const a = b;
        \\}
        \\
    );
}
