1

// Expected Result: console.log(1)

"test"

// Expected Result: console.log("test")

const num = 0;
num

// Expected Result: console.log(num)

num.toString()

// Expected Result: console.log(num.toString())

[1, 2, 3].map((n) => n);

// Expected Result: [1, 2, 3].map((n) => console.log(n))

const items = [
  { id:1 }
];

items.map((item) => item.id);

// Expected Result: items.map((item) => console.log(item.id))

(1, 2)

// Expected Result: console.log(1, 2)
