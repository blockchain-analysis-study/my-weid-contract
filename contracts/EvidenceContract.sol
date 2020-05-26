pragma solidity ^0.4.25;
pragma experimental ABIEncoderV2;

/*
 *       Copyright� (2018-2020) WeBank Co., Ltd.
 *
 *       This file is part of weidentity-contract.
 *
 *       weidentity-contract is free software: you can redistribute it and/or modify
 *       it under the terms of the GNU Lesser General Public License as published by
 *       the Free Software Foundation, either version 3 of the License, or
 *       (at your option) any later version.
 *
 *       weidentity-contract is distributed in the hope that it will be useful,
 *       but WITHOUT ANY WARRANTY; without even the implied warranty of
 *       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *       GNU Lesser General Public License for more details.
 *
 *       You should have received a copy of the GNU Lesser General Public License
 *       along with weidentity-contract.  If not, see <https://www.gnu.org/licenses/>.
 */

// 凭证合约 todo 入口合约
contract EvidenceContract {

    // block number map, hash as key
    //
    // 记录 Evidence Hash  和 存储该 Evidence 时的 blockNumber
    // (Evidence Hash => blockNumber)
    mapping(bytes32 => uint256) changed;


    // hash map, extra id string as key, hash as value
    mapping(string => bytes32) extraKeyMapping;

    // Evidence attribute change event including signature and logs
    //
    // 证据属性 更改事件，包括签名和日志
    // todo 主要用来存储 Evidence 信息
    event EvidenceAttributeChanged(
        bytes32[] hash,
        address[] signer,
        string[] sigs,
        string[] logs,
        uint256[] updated,
        uint256[] previousBlock
    );
    
    // Additional Evidence attribute change event
    event EvidenceExtraAttributeChanged(
        bytes32[] hash,
        address[] signer,
        string[] keys,
        string[] values,
        uint256[] updated,
        uint256[] previousBlock
    );


    // 根据 Evidence Hash 返回该Hash 对应的 BlockNumber
    function getLatestRelatedBlock(
        bytes32 hash
    ) 
        public 
        constant 
        returns (uint256) 
    {
        return changed[hash];
    }

    /**
     * Create evidence. Here, hash value is the key; signature and log are values. 
     */
    // 创建证据。 这里, 哈希值是 key； 签名和日志是 value。
    //
    // 支持同时创建多个 Evidence
    function createEvidence(
        bytes32[] hash,          // Evidence Hash todo 类似 `0xfbd1d8eed20af617cd5c48972e990adfeca7b694e77bd25e02ae1c23eea3fbec`  32byte
        address[] signer,        // 对Evidence进行签名的 账户 (该addr 对应的 priKey进行的签名)
        string[] sigs,           // priKey对 Evidence Hash 做的签名
        string[] logs,           // 对应SDK 的 Extra 字段, 无特殊要求 一般为 ""
        uint256[] updated        // timestamp
    )
        public
    {
        // todo  注意： 将传入Object计算Hash值生成存证上链，返回存证地址。传入的私钥将会成为链上存证的签名方。此签名方和凭证的Issuer可以不是同一方。
        //       当传入的object为null时，则会创建一个空的存证并返回其地址，空存证中仅包含签名方，不含Hash值。
        //       可以随后调用SetHashValue()方法，为空存证添加Hash值和签名。

        // 取的 Hash 的长度, 是 bytes32[]{Hash<32byte>, ..., Hash<32byte> }
        uint256 sigSize = hash.length;
        bytes32[] memory hashs = new bytes32[](sigSize);  // new bytes32[1]{}
        string[] memory sigss = new string[](sigSize);
        string[] memory logss = new string[](sigSize);
        address[] memory signers = new address[](sigSize);
        uint256[] memory updateds = new uint256[](sigSize);
        uint256[] memory previousBlocks = new uint256[](sigSize);  //

        // 遍历入参中 所有的 Evidence Hash
        for (uint256 i = 0; i < sigSize; i++) {
            bytes32 thisHash = hash[i];

            // todo 过滤掉 无签名 且 Hash不为空的 Evidence 信息
            if (isEqualString(sigs[i], "") && !isHashExist(thisHash)) {
                continue;
            }

            // copy 到对应数组的索引处
            hashs[i] = thisHash;
            sigss[i] = sigs[i];
            logss[i] = logs[i];
            signers[i] = signer[i];
            updateds[i] = updated[i];

            // 没操作一个 Evidence Hash 数据, 我们就记录 该Hash 的上一个 blockNumber
            previousBlocks[i] = changed[thisHash];

            // 记录当前Hash 的 blockNumber
            changed[thisHash] = block.number;
        }

        // 利用 Event 记录 Evidence
        emit EvidenceAttributeChanged(hashs, signers, sigss, logss, updateds, previousBlocks);
    }

    /**
     * Create evidence by extra key. As in the normal createEvidence case, this further allocates each evidence with an extra key in String format which caller can use to obtain the detailed info from within.
     */
    //
    // 通过额外的 Key 创建证据。
    // 与普通的createEvidence情况一样，todo 此方法还使用String格式的额外密钥分配每个证据，调用者可使用该密钥从内部获取详细信息。
    //
    // 支持一次存储多个 Evidence
    function createEvidenceWithExtraKey(
        bytes32[] hash,                     // Evidence Hash todo 类似 `0xfbd1d8eed20af617cd5c48972e990adfeca7b694e77bd25e02ae1c23eea3fbec`  32byte
        address[] signer,                   // 对Evidence进行签名的 账户 (该addr 对应的 priKey进行的签名)
        string[] sigs,                      // priKey对 Evidence Hash 做的签名
        string[] logs,                      // 对应SDK 的 Extra 字段, 无特殊要求 一般为 ""
        uint256[] updated,                  //
        string[] extraKey                   //
    )
        public
    {

        // 
        uint256 sigSize = hash.length;
        bytes32[] memory hashs = new bytes32[](sigSize);
        string[] memory sigss = new string[](sigSize);
        string[] memory logss = new string[](sigSize);
        address[] memory signers = new address[](sigSize);
        uint256[] memory updateds = new uint256[](sigSize);
        uint256[] memory previousBlocks = new uint256[](sigSize);
        for (uint256 i = 0; i < sigSize; i++) {
            bytes32 thisHash = hash[i];
            if (isEqualString(sigs[i], "") && !isHashExist(thisHash)) {
                continue;
            }
            hashs[i] = thisHash;
            sigss[i] = sigs[i];
            logss[i] = logs[i];
            signers[i] = signer[i];
            updateds[i] = updated[i];
            previousBlocks[i] = changed[thisHash];
            changed[thisHash] = block.number;
            extraKeyMapping[extraKey[i]] = thisHash;
        }
        emit EvidenceAttributeChanged(hashs, signers, sigss, logss, updateds, previousBlocks);
    }
    
     /**
      * Set arbitrary extra attributes to any EXISTING evidence.
     */
    function setAttribute(
        bytes32[] hash,
        address[] signer,
        string[] key,
        string[] value,
        uint256[] updated
    )
        public
    {
        uint256 sigSize = hash.length;
        bytes32[] memory hashs = new bytes32[](sigSize);
        string[] memory keys = new string[](sigSize);
        string[] memory values = new string[](sigSize);
        address[] memory signers = new address[](sigSize);
        uint256[] memory updateds = new uint256[](sigSize);
        uint256[] memory previousBlocks = new uint256[](sigSize);
        for (uint256 i = 0; i < sigSize; i++) {
            bytes32 thisHash = hash[i];
            if (isHashExist(thisHash)) {
                hashs[i] = thisHash;
                keys[i] = key[i];
                values[i] = value[i];
                signers[i] = signer[i];
                updateds[i] = updated[i];
                previousBlocks[i] = changed[thisHash];
                changed[thisHash] = block.number;
            }
        }
        emit EvidenceExtraAttributeChanged(hashs, signers, keys, values, updateds, previousBlocks);
    }

    function isHashExist(bytes32 hash) public constant returns (bool) {
        if (changed[hash] != 0) {
            return true;
        }
        return false;
    }

    function getHashByExtraKey(
        string extraKey
    )
        public
        constant
        returns (bytes32)
    {
        return extraKeyMapping[extraKey];
    }

    function isEqualString(string a, string b) private constant returns (bool) {	
        if (bytes(a).length != bytes(b).length) {	
            return false;	
        } else {	
            return keccak256(a) == keccak256(b);	
        }	
    }
}