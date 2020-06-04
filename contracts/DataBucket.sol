pragma solidity ^0.4.4;
pragma experimental ABIEncoderV2;

/*
 *       Copyright© (2018-2020) WeBank Co., Ltd.
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

// 数据桶合约
//
// 存储  CNS 数据
//
// 这里面是会某些 Admin 创建自己的一套 DID体系, 并记录了 哪些联盟加入了该Admin的DID体系
contract DataBucket {

    // 记录所有Hash 列表
    string[] hashList;      // all hash

    // 一个记录了 某个合约发行者的sender 地址和他发行的所有DID相关业务合约地址的总Hash的信息
    struct DataStruct {

        // 所有 DID 业务合约的地址的总Hash
        string hash;         // the hash

        // 某个合约部署人
        address owner;        // owner for hash

        // 启动当前 DataStruct 的 sender集
        address[] useAddress; // the user list for use this hash

        bool isUsed;           // the hash is be useed

        // 当前Hash 在Hash List中的us噢因
        uint256 index;        // the hash index in hashList

        // 创建时间
        uint256 timestamp;    // the first time for create hash
        mapping(bytes32 => string) kv; //the mapping for store the key--value
    }

    // (一个所有业务合约的 Hash 值  => DataStruct)
    mapping(string => DataStruct) hashData; // hash-->DataStruct
    
    uint8 constant private SUCCESS = 100;
    uint8 constant private NO_PERMISSION = 101;
    uint8 constant private THE_HASH_DOES_NOT_EXIST = 102;
    uint8 constant private THE_HASH_IS_USED = 103;
    uint8 constant private THE_HASH_IS_NOT_USED = 104;
    
    /**
     * put the key-value into hashData.
     * 
     * @param hash the hash
     * @param key the store key
     * @param value the value of the key
     * @return code the code for result
     */ 
    function put(
        string hash,  // 总的 合约地址的 总Hash
        bytes32 key,  // 当前合约类型, 一个字符串, 如: "WeIdContract"、"AuthorityIssuerController" 等等
        string value  // 对应的合约Addr
    ) 
        public 
        returns (uint8 code) 
    {
        DataStruct storage data = hashData[hash];
        //the first put hash  第一次时, 我们才 put Hash
        if (data.owner == address(0x0)) {
            data.hash = hash;
            data.owner = msg.sender;
            data.timestamp = now;
            pushHash(data);
            data.kv[key] = value;
            return SUCCESS;
        } else {
            // no permission
            if (data.owner != msg.sender) {
                 return NO_PERMISSION;
            }

            // 变更
            data.kv[key] = value;
            return SUCCESS;
        }
    }
    
    /**
     * push hash into hashList.
     * 
     * @param data the data for hash
     * 
     */ 
    function pushHash(
        DataStruct storage data
    ) 
        internal 
    {

        // 现在 hashList 中找到一个 空Hash 的索引 (用于填充空洞)
        // find the first empty index.
        int8 emptyIndex = -1;
        for (uint8 i = 0; i < hashList.length; i++) {

            // 是否为 空Hash
            if (isEqualString(hashList[i], "")) {
                emptyIndex = int8(i);
                break;
            }
        }

        // 如果不能找到存在 空Hash 的索引
        // can not find the empty index, push data to last
        if (emptyIndex == -1) {
            // 直接向末尾追加当前 Hash
            hashList.push(data.hash);

            // 记录索引
            data.index = hashList.length - 1;
        } else {
            // push data by index
            //
            // 否则, 填充空洞处
            uint8 index = uint8(emptyIndex);
            hashList[index] = data.hash;
            data.index = index;
        }
    }
    
    /**
     * get value by key in the hash data.
     * 
     * @param hash the hash
     * @param key get the value by this key
     * @return value the value
     */ 
    function get(
        string hash, 
        bytes32 key
    ) 
        public view
        returns (uint8 code, string value) 
    {
        DataStruct storage data = hashData[hash];
        if (data.owner == address(0x0)) {
            return (THE_HASH_DOES_NOT_EXIST, "");
        }
        return (SUCCESS, data.kv[key]);
    }
    
    /**
     * remove hash when the key is null, others remove the key
     * 
     * @param hash the hash
     * @param key the key
     * @return the code for result
     */ 
    function remove(
        string hash, 
        bytes32 key
    ) 
        public 
        returns (uint8 code) 
    {
        DataStruct memory data = hashData[hash];
        if (data.owner == address(0x0)) {
            return THE_HASH_DOES_NOT_EXIST;
        }
        if (key ==  bytes32("$admin")) {
            delete hashList[data.index];
            delete hashData[hash];
            return SUCCESS;
        }
        if (msg.sender != data.owner) {
            return NO_PERMISSION;
        }
        if (data.isUsed) {
            return THE_HASH_IS_USED;
        }
        if (key == bytes32(0x0)) {
            delete hashList[data.index];
            delete hashData[hash];
        } else {
            delete hashData[hash].kv[key];
        }
        return SUCCESS;
    }
    
    /**
     * 启用 当前Hash 中所有 合约
     * enable the hash.
     * @param hash the hash
     */
    function enableHash(
        string hash
    ) 
        public 
        returns (uint8) 
    {
        DataStruct storage data = hashData[hash];
        if (data.owner == address(0x0)) {
            return THE_HASH_DOES_NOT_EXIST;
        }
        
        if (!data.isUsed) {
            data.isUsed = true;
        }
        pushUseAddress(data);
        return SUCCESS;
    }
    
    /**
     * push the user into useAddress.
     */ 
    function pushUseAddress(
        DataStruct storage data
    ) 
        internal 
    {
        int8 emptyIndex = -1;
        for (uint8 i = 0; i < data.useAddress.length; i++) {
            if (data.useAddress[i] == msg.sender) {
                return;
            } 
            if (emptyIndex == -1 && data.useAddress[i] == address(0x0)) {
                emptyIndex = int8(i);
            }
        }
        if (emptyIndex == -1) {
            data.useAddress.push(msg.sender);
        } else {
            data.useAddress[uint8(emptyIndex)] = msg.sender;
        }
    }
    
    /**
     * remove the use Address from DataStruct.
     */ 
    function removeUseAddress(
        DataStruct storage data
    ) 
        internal 
    {
        uint8 index = 0;
        for (uint8 i = 0; i < data.useAddress.length; i++) {
            if (data.useAddress[i] == msg.sender) {
                index = i;
                break;
            }
        }
        delete data.useAddress[index];
    }
    
    /**
     * 只有全清掉 useAddress 集时, 才会返回 false
     * true is THE_HASH_IS_USED, false THE_HASH_IS_NOT_USED.
     */
    function hasUse(
        DataStruct storage data
    ) 
        internal 
        view 
        returns (bool)
    {
        for (uint8 i = 0; i < data.useAddress.length; i++) {
            if (data.useAddress[i] != address(0x0)) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * disable the hash
     * @param hash the hash
     */
    function disableHash(
        string hash
    ) 
        public 
        returns (uint8) 
    {
        DataStruct storage data = hashData[hash];
        if (data.owner == address(0x0)) {
            return THE_HASH_DOES_NOT_EXIST;
        }
        if (!data.isUsed) {
            return THE_HASH_IS_NOT_USED;
        }
        removeUseAddress(data);
        data.isUsed = hasUse(data); // 只有全清掉 useAddress 集时, 才会返回 false, 就是说只有全清掉 useAddress时才会将标识位的 true 改成 false
        return SUCCESS;
    }
    
    /**
     * get all hash by page.
     */ 
    function getAllHash(
        uint8 offset, 
        uint8 num
    ) 
        public 
        view
        returns (string[] hashs, address[] owners, uint256[] timestamps, uint8 nextIndex) 
    {
        hashs = new string[](num);
        owners = new address[](num);
        timestamps = new uint256[](num);
        uint8 index = 0;
        uint8 next = 0;
        for (uint8 i = offset; i < hashList.length; i++) {
            string storage hash = hashList[i];
            if (!isEqualString(hash, "")) {
                DataStruct memory data = hashData[hash];
                hashs[index] = hash;
                owners[index] = data.owner;
                timestamps[index] = data.timestamp;
                index++;
                if (index == num && i != hashList.length - 1) {
                    next = i + 1;
                    break;
                }
            }
        }
        return (hashs, owners, timestamps, next);
    }
    
    function isEqualString(
        string a, 
        string b
    ) 
        private 
        constant 
        returns (bool) 
    {
        if (bytes(a).length != bytes(b).length) {
            return false;
        } else {
            return keccak256(a) == keccak256(b);
        }
    }
}