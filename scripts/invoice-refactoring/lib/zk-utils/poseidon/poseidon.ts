import { poseidon1, poseidon2, poseidon3, poseidon4, poseidon5, poseidon6 } from "poseidon-lite";

export const poseidon_hash_1 = (value: number | bigint | number[] | bigint[]) => {
  const input = Array.isArray(value) ? value : [value];
  return poseidon1(input);
}

export const poseidon_hash_2 = (values: number[] | bigint[]) => {
  return poseidon2(values);
}

export const poseidon_hash_3 = (values: number[] | bigint[]) => {
  return poseidon3(values);
}

export const poseidon_hash_4 = (values: number[] | bigint[]) => {
  return poseidon4(values);
}

export const poseidon_hash_5 = (values: number[] | bigint[]) => {
  return poseidon5(values);
}

export const poseidon_hash_6 = (values: number[] | bigint[]) => {
  return poseidon6(values);
}