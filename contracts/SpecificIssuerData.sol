pragma solidity ^0.4.4;
/*
 *       Copyright© (2019) WeBank Co., Ltd.
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

/**
 * @title SpecificIssuerData
 * Stores data about issuers with specific types.
 */

// todo 发行人的具体描述 数据合约
contract SpecificIssuerData {

    // Error codes
    // 错误码
    uint constant private RETURN_CODE_SUCCESS = 0;
    uint constant private RETURN_CODE_FAILURE_ALREADY_EXISTS = 500501;
    uint constant private RETURN_CODE_FAILURE_NOT_EXIST = 500502;
    uint constant private RETURN_CODE_FAILURE_EXCEED_MAX = 500503;


    // todo 发行人 类型 实体
    struct IssuerType {
        // typeName as index, dynamic array as getAt function and mapping as search
        //
        // typeName作为索引，动态数组作为getAt函数，映射作为搜索
        bytes32 typeName;

        // 存储 所有注册了当前 发行人类型的 DID集
        address[] fellow;

        // 存储 当前类型的发行人的 DID 集 (去重用)
        //
        // (DID => bool)
        mapping (address => bool) isFellow;

        // 当前 类型发行人 的拓展信息
        bytes32[8] extra;
    }


    // 存储 发行人的 Name => 发行人类型信息
    //
    // (typeName => issuerType)
    mapping (bytes32 => IssuerType) private issuerTypeMap;


    // 注册一个新的 发行者 类型
    function registerIssuerType(bytes32 typeName) public returns (uint) {
        // 该 发行人的类型 name  是否已经存在
        if (isIssuerTypeExist(typeName)) {
            return RETURN_CODE_FAILURE_ALREADY_EXISTS;
        }
        address[] memory fellow;
        bytes32[8] memory extra;

        // 初始化一个 发行人信息 实例
        IssuerType memory issuerType = IssuerType(typeName, fellow, extra);
        issuerTypeMap[typeName] = issuerType;
        return RETURN_CODE_SUCCESS;
    }

    // 添加当前类型发行人的拓展信息
    function addExtraValue(bytes32 typeName, bytes32 extraValue) public returns (uint) {
        if (!isIssuerTypeExist(typeName)) {
            return RETURN_CODE_FAILURE_NOT_EXIST;
        }
        IssuerType issuerType = issuerTypeMap[typeName];
        for (uint index = 0; index < 8; index++) {
            if (issuerType.extra[index] == bytes32(0)) {
                issuerType.extra[index] = extraValue;
                break;
            }
        }
        if (index == 8) {
            return RETURN_CODE_FAILURE_EXCEED_MAX;
        }
        return RETURN_CODE_SUCCESS;
    }

    // 获取当前类型发行人的拓展信息
    function getExtraValue(bytes32 typeName) public constant returns (bytes32[8]) {
        bytes32[8] memory extraValues;
        if (!isIssuerTypeExist(typeName)) {
            return extraValues;
        }
        IssuerType issuerType = issuerTypeMap[typeName];
        for (uint index = 0; index < 8; index++) {
            extraValues[index] = issuerType.extra[index];
        }
        return extraValues;
    }

    // 该 发行人的类型 name  是否已经存在
    function isIssuerTypeExist(bytes32 name) public constant returns (bool) {
        if (issuerTypeMap[name].typeName == bytes32(0)) {
            return false;
        }
        return true;
    }


    // 注册一个 typeName 类型的发行人 (绑定该 DID)
    function addIssuer(bytes32 typeName, address addr) public returns (uint) {
        if (isSpecificTypeIssuer(typeName, addr)) {
            return RETURN_CODE_FAILURE_ALREADY_EXISTS;
        }
        if (!isIssuerTypeExist(typeName)) {
            return RETURN_CODE_FAILURE_NOT_EXIST;
        }

        // 将 档期啊 DID 追加到 该typeName 对应的发行人类型信息中
        issuerTypeMap[typeName].fellow.push(addr);          // DID 追加到数组中
        issuerTypeMap[typeName].isFellow[addr] = true;      // DID 追加到标识位 Map中
        return RETURN_CODE_SUCCESS;
    }

    // 移除一个 typeName 类型发行人 DID
    function removeIssuer(bytes32 typeName, address addr) public returns (uint) {
        if (!isSpecificTypeIssuer(typeName, addr) || !isIssuerTypeExist(typeName)) {
            return RETURN_CODE_FAILURE_NOT_EXIST;
        }

        // 获取 所有 typeName 类型发行人的 DID 集
        address[] memory fellow = issuerTypeMap[typeName].fellow;

        // 逐个遍历
        uint dataLength = fellow.length;
        for (uint index = 0; index < dataLength; index++) {
            if (addr == fellow[index]) {
                break;
            }
        }

        // 如果当前被删除的 DID 不是 队列中最后一个, 需要在移除当前DID后，将队列中最后一个 DID填充到当前位置
        if (index != dataLength-1) {
            issuerTypeMap[typeName].fellow[index] = issuerTypeMap[typeName].fellow[dataLength-1];
        }
        delete issuerTypeMap[typeName].fellow[dataLength-1];
        // 递减数组额 length
        issuerTypeMap[typeName].fellow.length--;
        // 将 map 中的当前 DID 的标识位设置为 false
        issuerTypeMap[typeName].isFellow[addr] = false;
        return RETURN_CODE_SUCCESS;
    }


    // 判断当前 DID 是否已已经 注册过该发行人类型信息了
    function isSpecificTypeIssuer(bytes32 typeName, address addr) public constant returns (bool) {
        if (issuerTypeMap[typeName].isFellow[addr] == false) {
            return false;
        }
        return true;
    }


    // 根据 start 索引往后最多取 50 个DID
    function getSpecificTypeIssuers(bytes32 typeName, uint startPos) public constant returns (address[50]) {
        address[50] memory fellow;
        if (!isIssuerTypeExist(typeName)) {
            return fellow;
        }

        // Calculate actual dataLength via batch return for better perf
        uint totalLength = getSpecificTypeIssuerLength(typeName);
        uint dataLength;
        if (totalLength < startPos) {
            return fellow;
        } else if (totalLength <= startPos + 50) {
            dataLength = totalLength - startPos;
        } else {
            dataLength = 50;
        }

        // dynamic -> static array data copy
        for (uint index = 0; index < dataLength; index++) {
            fellow[index] = issuerTypeMap[typeName].fellow[index + startPos];
        }
        return fellow;
    }


    // 获取当前 类型的发行人的总数量
    function getSpecificTypeIssuerLength(bytes32 typeName) public constant returns (uint) {
        if (!isIssuerTypeExist(typeName)) {
            return 0;
        }
        return issuerTypeMap[typeName].fellow.length;
    }
}