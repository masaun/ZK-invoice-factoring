use poseidon::poseidon::bn254::{hash_1, hash_2, hash_3, hash_4, hash_5};

pub fn poseidon_hash_1(input: [Field; 1]) -> Field {
    hash_1(input)
}

pub fn poseidon_hash_2(input: [Field; 2]) -> Field {
    hash_2(input)
}

pub fn poseidon_hash_3(input: [Field; 3]) -> Field {
    hash_3(input)
}

pub fn poseidon_hash_4(input: [Field; 4]) -> Field {
    hash_4(input)
}

pub fn poseidon_hash_5(input: [Field; 5]) -> Field {
    hash_5(input)
}