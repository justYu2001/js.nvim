const returnPrimitiveValue = () => {
  1
};

// Expected Result: return 1

const returnOneLineObject = () => {
  { a:1 }
};

// Expected Result: return { a: 1 }

const returnMultiLineObject = () => {
  {
    id: 1,
    name: "test",
  }
};

// Expected Result:
// return {
//   id: 1,
//   name: "test"
// }

const returnOneLineFunctionCall = () => {
  [1, 2, 3].filter((n) => n > 1)
};

// Expected Result: return [1, 2, 3].filter((n) => n > 1)

const returnMultiLineFunctionCall = () => {
  JSON.stringify({
    id: 1,
    name: "test",
  })
};

// Expected Result:
// return JSON.stringify({
//  id: 1,
//  name: "test",
//})

