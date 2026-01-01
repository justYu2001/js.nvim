const expressionCase = () => {
  console.log(1);
};

// Expected Result: const expressionCase = () => console.log(1);

const returnPrimitiveValue = () => {
  return 1;
};

// Expected Result: const returnPrimitiveValue = () => 1;

const returnObject = () => {
  return {
    name: "test",
    id: 1,
  };
};

// Expected Result:
// const returnObject = () => ({
//   name: 'test',
//   id: 1,
// });

[1, 2, 3].map((n) => {
  return n + 1;
});

// Expected Result: [1, 2, 3].map((n) => n + 1);

[1, 2, 3].map((n) => {
  console.log(n);
});

// Expected Result: [1, 2, 3].map((n) => console.log(n));

const Tag = () => {
  return (
    <button
      onClick={() => {
        console.log(1);
      }}
    >
      test
    </button>
  );
};

// Expected Result: <button onClick={() => console.log(1)}>
