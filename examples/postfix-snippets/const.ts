1

// Expected Result: const $0 = 1

const n = 1
n

// Expected Result: const $0 = n

{ a: 1 }

// Expected Result: const $0 = { a: 1 }

{
  id: 1,
  name: "test",
}

// Expected Result:
// const $0 = {
//   id: 1,
//   name: "test",
// }

const sleep = (time: number) => {
  return new Promise((resolve) => setTimeout(resolve, time));
};

await sleep(1000)

// Expected Result: const $0 = await sleep(1000)

JSON.stringify({
  id: 1,
  name: "test"
})

// Expected Result :
// const $0 = JSON.stringify({
//   id: 1,
//   name: "test"
// })

const fn = (num: number) => {
  (num % 3 ||
    num % 4 ||
    num % 5 ||
    num % 6
  )
};

// Expected Result:
// const $0 = (num % 3 ||
//   num % 4 ||
//   num % 5 ||
//   num % 6
// )

const temp = 1
!temp

// Expected Result: const  = ! temp
