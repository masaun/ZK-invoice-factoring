import { IMT } from "@zk-kit/imt";
import { poseidon_hash_1, poseidon_hash_2, poseidon_hash_3 } from "../poseidon/poseidon.ts";
import { TREE_ARITY, TREE_DEPTH, TREE_ZERO_VALUE } from "../constants.ts";

export * from "../constants.ts";

// @dev - Create an Incremental Merkle Tree with given leaves
export const getIncrementalMerkleTree = async (treeLeaves: number[]) => {
  const imTree = new IMT(
    poseidon_hash_2,
    TREE_DEPTH,
    TREE_ZERO_VALUE,
    TREE_ARITY,
    treeLeaves
  );

  return { imTree };
};

// @dev - Get the index of a leaf in the Incremental Merkle Tree
export const getIndexOfLeaf = async (imTree: IMT, leaf: number) => {
    return imTree.indexOf(leaf);
}

// @dev - Create an Incremental Merkle Proof for a given leaf index
export const createIncrementalMerkleProof = async (imTree: IMT, leafIndex: number) => {
    const merkleProof = imTree.createProof(leafIndex);
    return merkleProof;
}

// @dev - Get the Incremental Merkle Root
export const getIncrementalMerkleRoot = async (imTree: IMT) => {
    return imTree.root;
}

