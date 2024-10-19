const std = @import("std");

pub const Scanner = struct {
    source: []const u8,
    start: u32,
    current: u32,
    line: u32,

    pub fn init(source: []const u8) Scanner {
        return Scanner{
            .source = source,
            .start = 0,
            .current = 0,
            .line = 1,
        };
    }

    pub fn scanToken(this: *Scanner) Token {
        this.skipWhiteSpace();
        this.start = this.current;

        if (this.isAtEnd()) {
            return this.makeToken(.EOF);
        }

        const c = this.advance();

        if (isDigit(c)) {
            return this.number();
        }

        if (isAlpha(c)) {
            return this.identifier();
        }

        switch (c) {
            '(' => return this.makeToken(.LEFT_PAREN),
            ')' => return this.makeToken(.RIGHT_PAREN),
            '{' => return this.makeToken(.LEFT_BRACE),
            '}' => return this.makeToken(.RIGHT_BRACE),
            ';' => return this.makeToken(.SEMICOLON),
            ',' => return this.makeToken(.COMMA),
            '.' => return this.makeToken(.DOT),
            '-' => return this.makeToken(.MINUS),
            '+' => return this.makeToken(.PLUS),
            '/' => return this.makeToken(.SLASH),
            '*' => return this.makeToken(.STAR),
            '!' => return this.makeToken(if (this.match('=')) .BANG_EQUAL else .BANG),
            '=' => return this.makeToken(if (this.match('=')) .EQUAL_EQUAL else .EQUAL),
            '>' => return this.makeToken(if (this.match('=')) .GREATER_EQUAL else .GREATER),
            '<' => return this.makeToken(if (this.match('=')) .LESS_EQUAL else .LESS),
            '"' => return this.string(),

            else => return this.errorToken("Unexpected character"),
        }

        return this.errorToken("Unexpected character");
    }

    fn advance(this: *Scanner) u8 {
        this.current += 1;
        return this.source[this.current - 1];
    }

    fn match(this: *Scanner, expected: u8) bool {
        if (this.isAtEnd()) {
            return false;
        }
        if (this.source[this.current] != expected) {
            return false;
        }
        this.current += 1;
        return true;
    }

    fn skipWhiteSpace(this: *Scanner) void {
        while (true) {
            const c = this.peek();
            switch (c) {
                ' ', '\r', '\t' => _ = this.advance(),
                '\n' => {
                    this.line += 1;
                    _ = this.advance();
                },
                '/' => {
                    if (this.peekNext() == '/') {
                        while (this.peek() != '\n' and !this.isAtEnd()) {
                            _ = this.advance();
                        }
                    } else {
                        return;
                    }
                },
                else => break,
            }
        }
    }

    fn string(this: *Scanner) Token {
        while (this.peek() != '"' and !this.isAtEnd()) {
            if (this.peek() == '\n') {
                this.line += 1;
            }
            _ = this.advance();
        }

        if (this.isAtEnd()) {
            return this.errorToken("Unterminated string!");
        }

        _ = this.advance();
        return this.makeToken(.STRING);
    }

    fn number(this: *Scanner) Token {
        while (isDigit(this.peek())) {
            _ = this.advance();
        }

        if (this.peek() == '.' and isDigit(this.peekNext())) {
            _ = this.advance();

            while (isDigit(this.peek())) {
                _ = this.advance();
            }
        }

        return this.makeToken(.NUMBER);
    }

    fn identifier(this: *Scanner) Token {
        while (isDigit(this.peek()) or isAlpha(this.peek())) {
            _ = this.advance();
        }

        return this.makeToken(this.identifierType());
    }

    fn identifierType(this: *Scanner) TokenType {
        switch (this.source[this.start]) {
            'a' => return this.checkKeyword(1, 2, "nd", .AND),
            'c' => return this.checkKeyword(1, 4, "lass", .CLASS),
            'e' => return this.checkKeyword(1, 3, "lse", .ELSE),
            'i' => return this.checkKeyword(1, 1, "f", .IF),
            'n' => return this.checkKeyword(1, 2, "il", .NIL),
            'o' => return this.checkKeyword(1, 1, "r", .OR),
            'p' => return this.checkKeyword(1, 4, "rint", .PRINT),
            'r' => return this.checkKeyword(1, 5, "eturn", .RETURN),
            's' => return this.checkKeyword(1, 4, "uper", .SUPER),
            'v' => return this.checkKeyword(1, 2, "ar", .VAR),
            'w' => return this.checkKeyword(1, 4, "hile", .WHILE),
            'f' => {
                if (this.current - this.start > 1) {
                    return switch (this.source[this.start + 1]) {
                        'a' => this.checkKeyword(2, 3, "lse", .FALSE),
                        'o' => this.checkKeyword(2, 1, "r", .FOR),
                        'u' => this.checkKeyword(2, 1, "n", .FUN),

                        else => .IDENTIFIER,
                    };
                }
            },
            't' => {
                if (this.current - this.start > 1) {
                    return switch (this.source[this.start + 1]) {
                        'h' => this.checkKeyword(2, 2, "is", .THIS),
                        'r' => this.checkKeyword(2, 2, "ue", .TRUE),

                        else => .IDENTIFIER,
                    };
                }
            },

            else => {},
        }
        return .IDENTIFIER;
    }

    fn checkKeyword(this: *Scanner, start: u32, length: u32, rest: []const u8, tokenType: TokenType) TokenType {
        if (this.current - this.start != start + length) {
            return .IDENTIFIER;
        }

        for (this.source[this.start + start .. this.current], rest) |a, b| {
            if (a != b) {
                return .IDENTIFIER;
            }
        }

        return tokenType;
    }

    fn peek(this: *Scanner) u8 {
        if (this.isAtEnd()) {
            return 0;
        }
        return this.source[this.current];
    }

    fn peekNext(this: *Scanner) u8 {
        if (this.isAtEnd()) {
            return 0;
        }
        return this.source[this.current + 1];
    }

    fn isAtEnd(this: *Scanner) bool {
        return this.current == this.source.len - 1;
    }

    fn makeToken(this: *Scanner, tokenType: TokenType) Token {
        return Token{
            .tokenType = tokenType,
            .source = this.source[this.start..this.current],
            .line = this.line,
        };
    }

    fn errorToken(this: *Scanner, message: []const u8) Token {
        return Token{
            .tokenType = .ERROR,
            .source = message,
            .line = this.line,
        };
    }
};

pub const Token = struct {
    tokenType: TokenType,
    source: []const u8,
    line: u32,
};

pub const TokenType = enum {
    // Single-character tokens.
    LEFT_PAREN,
    RIGHT_PAREN,
    LEFT_BRACE,
    RIGHT_BRACE,
    COMMA,
    DOT,
    MINUS,
    PLUS,
    SEMICOLON,
    SLASH,
    STAR,
    // One or two character tokens.
    BANG,
    BANG_EQUAL,
    EQUAL,
    EQUAL_EQUAL,
    GREATER,
    GREATER_EQUAL,
    LESS,
    LESS_EQUAL,
    // Literals.
    IDENTIFIER,
    STRING,
    NUMBER,
    // Keywords.
    AND,
    CLASS,
    ELSE,
    FALSE,
    FOR,
    FUN,
    IF,
    NIL,
    OR,
    PRINT,
    RETURN,
    SUPER,
    THIS,
    TRUE,
    VAR,
    WHILE,

    ERROR,
    EOF,
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_';
}
