pragma solidity ^0.4.4;
/*
 *       Copyright© (2018-2019) WeBank Co., Ltd.
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

import "./AuthorityIssuerData.sol";
import "./RoleController.sol";

/**
 * @title AuthorityIssuerController
 * Issuer contract manages authority issuer info.
 */
// 发行人合约 管理授权发行人信息
//
// todo 权威发行人 控制流程合约
contract AuthorityIssuerController {

    // 权威发行人 数据合约
    AuthorityIssuerData private authorityIssuerData;
    // 权限控制合约
    RoleController private roleController;

    // Event structure to store tx records
    //
    // 用于存储TX记录的事件结构

    // 添加操作
    uint constant private OPERATION_ADD = 0;

    // 移除操作
    uint constant private OPERATION_REMOVE = 1;

    // 空数组的长度
    uint constant private EMPTY_ARRAY_SIZE = 1;

    // 记录发行人的 操作动作的event
    event AuthorityIssuerRetLog(uint operation, uint retCode, address addr);

    // Constructor.
    // 构造函数, 初始化对应的 权威发行人数据合约 和 权限控制合约
    function AuthorityIssuerController(
        address authorityIssuerDataAddress,
        address roleControllerAddress
    ) 
        public 
    {
        authorityIssuerData = AuthorityIssuerData(authorityIssuerDataAddress);
        roleController = RoleController(roleControllerAddress);
    }

    // 添加权威发行人
    function addAuthorityIssuer(
        address addr,               // issuer 的 weId
        bytes32[16] attribBytes32,  // byte[name]
        int[16] attribInt,          // byte[timestamp]
        bytes accValue              // 授权方累积判定值 todo 问了官方的人, 说是 该发行人所有发行的 Credential 中 素数的乘积 Accumulator 的值 (有凭证撤销的时候, 这个值就会改变)
    )
        public
    {

        // 校验 交易的原始发送者 是否有变更 权威发行者 信息的权限 ??
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_AUTHORITY_ISSUER())) {

            // 记录失败 event
            AuthorityIssuerRetLog(OPERATION_ADD, roleController.RETURN_CODE_FAILURE_NO_PERMISSION(), addr);
            return;
        }

        // 校验权限通过时, 调用 权威发行人 数据合约, 添加 权威发行人信息
        uint result = authorityIssuerData.addAuthorityIssuerFromAddress(addr, attribBytes32, attribInt, accValue);
        AuthorityIssuerRetLog(OPERATION_ADD, result, addr);
    }

    // 删除 did
    function removeAuthorityIssuer(
        address addr
    ) 
        public 
    {

        // 判断 tx的原始发送者是否具备 更改权威发行者信息权限
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_AUTHORITY_ISSUER())) {
            AuthorityIssuerRetLog(OPERATION_REMOVE, roleController.RETURN_CODE_FAILURE_NO_PERMISSION(), addr);
            return;
        }

        // 删除did信息
        uint result = authorityIssuerData.deleteAuthorityIssuerFromAddress(addr);
        // 记录事件
        AuthorityIssuerRetLog(OPERATION_REMOVE, result, addr);
    }

    // 根据起始位置和个数返回对应的 子数组片段
    function getAuthorityIssuerAddressList(
        uint startPos,  // 起始位置
        uint num        // 本次提取的个数
    ) 
        public 
        constant 
        returns (address[]) 
    {
        // 获取在 权威发行者 数据合约中的 did数组的长度
        uint totalLength = authorityIssuerData.getDatasetLength();

        uint dataLength;
        // Calculate actual dataLength
        //
        // 计算 确切的数据长度

        // 当入参的起始索引 大于 数组总长度时, 返回一个空数组
        if (totalLength < startPos) {
            // 构建一个 空数组返回
            return new address[](EMPTY_ARRAY_SIZE);

            // 如果从起始处到提取的个数末尾的终止索引 大于 数组总长度
            // 则, 我们只提取到 末尾
        } else if (totalLength <= startPos + num) {
            dataLength = totalLength - startPos;
        } else {
            dataLength = num;
        }

        // 先创建 dataLength 大小的空数组
        address[] memory issuerArray = new address[](dataLength);

        // 逐个从 权威发行者 did数组中提取相应的did
        for (uint index = 0; index < dataLength; index++) {
            issuerArray[index] = authorityIssuerData.getAuthorityIssuerFromIndex(startPos + index);
        }
        return issuerArray;
    }


    // 获取对应did的 name和创建时的timestamp
    function getAuthorityIssuerInfoNonAccValue(
        address addr  // 权威发行者的did
    )
        public
        constant
        returns (bytes32[], int[])
    {
        // Due to the current limitations of bcos web3j, return dynamic bytes32 and int array instead.
        //
        // 由于bcos web3j的当前限制，请返回 动态bytes32和int数组。
        bytes32[16] memory allBytes32;
        int[16] memory allInt;
        (allBytes32, allInt) = authorityIssuerData.getAuthorityIssuerInfoNonAccValue(addr);

        // 固定数组 转成 动态数组
        bytes32[] memory finalBytes32 = new bytes32[](16);
        int[] memory finalInt = new int[](16);

        // 将元素 copy 到动态数组中
        for (uint index = 0; index < 16; index++) {
            finalBytes32[index] = allBytes32[index];
            finalInt[index] = allInt[index];
        }
        return (finalBytes32, finalInt);
    }


    //  判断 did 是否是 权威发行者
    function isAuthorityIssuer(
        address addr
    ) 
        public 
        constant 
        returns (bool) 
    {
        return authorityIssuerData.isAuthorityIssuer(addr);
    }


    // 根据 name 获取 did
    function getAddressFromName(
        bytes32 name
    )
        public
        constant
        returns (address)
    {
        return authorityIssuerData.getAddressFromName(name);
    }
}