# Function to Arrow Function - Limitations

This document explains cases where the "Convert to arrow function" code action is intentionally NOT available, and the rationale behind these limitations.

## Cases Not Converted

### 1. Named Function Expressions

**Example:**
```javascript
const foo = function bar() {
  return bar() // Recursive call using internal name
}
```

**Why:** Function expressions can have an internal name that's different from the variable name. This internal name is used for recursion and is available within the function body. Arrow functions don't have internal names.

**After conversion (LOSES functionality):**
```javascript
const foo = () => {
  return bar() // ❌ ERROR: bar is not defined
}
```

**Impact:** The internal name `bar` is lost, breaking recursive calls or any code that references the function's own name.

---

### 2. Functions Using `this` Keyword

**Example:**
```javascript
function processItem() {
  return this.value * 2
}
```

**Why:** Regular functions have their own `this` binding (dynamic), while arrow functions inherit `this` from their lexical scope.

**After conversion (DIFFERENT behavior):**
```javascript
const processItem = () => {
  return this.value * 2 // 'this' now refers to outer scope
}
```

**Impact:** The `this` context changes, potentially breaking the code when the function is used as a method or with `.call()`, `.apply()`, or `.bind()`.

---

### 3. Functions Using `arguments` Object

**Example:**
```javascript
function sum() {
  return Array.from(arguments).reduce((a, b) => a + b, 0)
}
```

**Why:** Regular functions have an `arguments` object containing all passed arguments. Arrow functions don't have `arguments`.

**After conversion (BREAKS code):**
```javascript
const sum = () => {
  return Array.from(arguments).reduce((a, b) => a + b, 0)
  // ❌ ERROR: arguments is not defined
}
```

**Impact:** Code relying on `arguments` will break. Modern alternative: use rest parameters `(...args)`.

---

### 4. Generator Functions

**Example:**
```javascript
function* generateSequence() {
  yield 1
  yield 2
  yield 3
}
```

**Why:** Arrow functions cannot be generators. The `function*` syntax is required for generator functions.

**After conversion (IMPOSSIBLE):**
```javascript
const generateSequence = * () => { // ❌ Invalid syntax
  yield 1
}
```

**Impact:** Generator functionality cannot be replicated with arrow functions.

---

## Conversions That ARE Supported

### ✓ Simple Function Declarations
```javascript
function add(a, b) { return a + b }
// ↓
const add = (a, b) => a + b
```

### ✓ Async Functions
```javascript
async function fetchData() { return data }
// ↓
const fetchData = async () => data
```

### ✓ Method Definitions
```javascript
const obj = {
  method() { return 1 }
}
// ↓
const obj = {
  method: () => 1
}
```

### ✓ TypeScript Type Annotations
```typescript
function add(x: number, y: number): number { return x + y }
// ↓
const add = (x: number, y: number): number => x + y
```

### ✓ Object Returns (auto-wrapped)
```javascript
function getUser() { return { name: 'John' } }
// ↓
const getUser = () => ({ name: 'John' })
```

---

## Important Behavioral Differences

Even when conversion IS supported, be aware:

### Hoisting Behavior Changes

**Before (function declaration):**
```javascript
greet() // ✓ Works due to hoisting
function greet() { console.log('Hi') }
```

**After (const declaration):**
```javascript
greet() // ❌ ReferenceError: Cannot access before initialization
const greet = () => console.log('Hi')
```

**Impact:** Function declarations are hoisted; const declarations are not. Code order matters.

### Constructor Usage

**Before:**
```javascript
function Person(name) {
  this.name = name
}
const p = new Person('John') // ✓ Works
```

**After:**
```javascript
const Person = (name) => {
  this.name = name
}
const p = new Person('John') // ❌ TypeError: Person is not a constructor
```

**Impact:** Arrow functions cannot be used as constructors with `new`.

---

## Summary

The conversion is **conservative by design** to prevent breaking changes. If a function uses features incompatible with arrow functions (`this`, `arguments`, generators) or has special semantics (named expressions), the code action won't be offered.

For more information, see:
- [MDN: Arrow Functions](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions/Arrow_functions)
- [MDN: Regular Functions](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Functions)
