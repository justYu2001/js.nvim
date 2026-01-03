function test() {
  console.log(1)
}

// Expected Result: const test = () => console.log(1)

function add(a: number, b: number) {
  return a + b
}

// Expected Result: const add = (a: number, b : number) => a + b

function returnObject() {
  return {
    id: 1,
    name: "test",
  }
}

// Expected Result:
// const returnObject = () => ({
//   id: 1,
//   name: "test",
// })

const obj = {
  foo() {
    console.log(1)
  }
}

// Expected Result:
// foo: () => console.log(1)

async function asyncFn () {
  return await fetch("/api");
}

// Expected Result: const asyncFn = async () => fetch("/api") 

const namedFunction = function () {
  console.log(1)
}

// Expected Result: const namedFunction = () => console.log(1)

// Expect won't show code actions for the following cases:

function* g() {
  yield 1;
}

function fnUseThis() {
  return this.value
}

function fnUseArguments() {
  return arguments[0]
}

