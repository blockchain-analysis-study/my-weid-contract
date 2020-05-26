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

import "./RoleController.sol";

/**
 * @title AuthorityIssuerData
 * Authority Issuer data contract.
 */

// 权威发行人 数据合约
contract AuthorityIssuerData {

    // Error codes
    //
    // 一些错误码
    uint constant private RETURN_CODE_SUCCESS = 0;
    uint constant private RETURN_CODE_FAILURE_ALREADY_EXISTS = 500201;
    uint constant private RETURN_CODE_FAILURE_NOT_EXIST = 500202;
    uint constant private RETURN_CODE_NAME_ALREADY_EXISTS = 500203;


    // todo 权威发行人的数据结构
    struct AuthorityIssuer {
        // [0]: name  第一个元素是 权威发行者的name
        bytes32[16] attribBytes32; // 16个 byte32 的数据
        // [0]: create date  第一个元素是 创建权威发行者时的 timestamp
        int[16] attribInt; // 16个 int数据
        bytes accValue;    // ??
    }


    // 存储 权威发行者实体信息
    // (did => info)
    mapping (address => AuthorityIssuer) private authorityIssuerMap;

    // 存储 权威发行者的did
    address[] private authorityIssuerArray;

    // 存储权威发行者的 name
    // (name => did)
    mapping (bytes32 => address) private uniqueNameMap;


    // 权限控制合约
    RoleController private roleController;

    // Constructor  todo 构造函数 只有部署的时候才会被调用一次而已
    function AuthorityIssuerData(address addr) public {
        // 还是求得 RoleController(addr) 合约实例 ??
        roleController = RoleController(addr);
    }


    //  判断 did 是否是 权威发行者
    function isAuthorityIssuer(
        address addr
    ) 
        public 
        constant 
        returns (bool) 
    {
        // Use LOCAL INFO here, not the RoleController data
        // The latter one might lose track in the fresh-deploy or upgrade case
        //
        // 在此处使用LOCAL INFO，而不是RoleController数据
        // 后者可能会在重新部署或升级的情况下丢失

        // 判断 权威发行者的DID对应的 权威发行者实体信息中的属性字段的第一个 byte32 (name) 是否为空
        if (authorityIssuerMap[addr].attribBytes32[0] == bytes32(0)) {
            return false;
        }
        return true;
    }


    // 添加权威发行者信息
    function addAuthorityIssuerFromAddress(
        address addr,                   // 权威发行者的 DID
        bytes32[16] attribBytes32,      // byte[name, 16]
        int[16] attribInt,              // byte[timestamp, 16]
        bytes accValue                  //
    )
        public
        returns (uint)
    {
        // 是否已经存在了
        if (isAuthorityIssuer(addr)) {
            return RETURN_CODE_FAILURE_ALREADY_EXISTS;
        }

        // name 是否已经存在
        if (isNameDuplicate(attribBytes32[0])) {
            return RETURN_CODE_NAME_ALREADY_EXISTS;
        }

        // 校验 交易的原始发送者 是否有变更 权威发行者 信息的权限
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_AUTHORITY_ISSUER())) {
            return roleController.RETURN_CODE_FAILURE_NO_PERMISSION();
        }

        // 给 权威发行者的DID 添加角色信息 <权威发行者角色>
        roleController.addRole(addr, roleController.ROLE_AUTHORITY_ISSUER());

        // 根据数据, 构造相关的 权威发行者信息
        AuthorityIssuer memory authorityIssuer = AuthorityIssuer(attribBytes32, attribInt, accValue);
        // 添加权威发行者的信息
        authorityIssuerMap[addr] = authorityIssuer;

        // 将 did 存储到数组中
        authorityIssuerArray.push(addr);

        // 存入 name => did 集
        uniqueNameMap[attribBytes32[0]] = addr;
        return RETURN_CODE_SUCCESS;
    }


    // 删除权威发行者信息
    function deleteAuthorityIssuerFromAddress(
        address addr
    ) 
        public 
        returns (uint)
    {

        // 是否是 权威发行人
        if (!isAuthorityIssuer(addr)) {
            return RETURN_CODE_FAILURE_NOT_EXIST;
        }

        // 当前tx的原始发送者, 是否有权限更改 权威发行人信息
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_AUTHORITY_ISSUER())) {
            return roleController.RETURN_CODE_FAILURE_NO_PERMISSION();
        }

        // 移除掉 该 did 的权威发行人角色信息
        roleController.removeRole(addr, roleController.ROLE_AUTHORITY_ISSUER());
        // 移除掉当前 权威发行人的 name信息
        uniqueNameMap[authorityIssuerMap[addr].attribBytes32[0]] = address(0x0);
        // 移除掉当前 权威发行人的信息
        delete authorityIssuerMap[addr];
        uint datasetLength = authorityIssuerArray.length;
        // 移除掉当前 权威发行人的 did
        for (uint index = 0; index < datasetLength; index++) {
            if (authorityIssuerArray[index] == addr) { 
                break; 
            }
        }
        // 只有被移除的did位置不是末尾的时
        if (index != datasetLength-1) {
            // 将 did 数组末尾的 填充到被移除的did 的位置
            authorityIssuerArray[index] = authorityIssuerArray[datasetLength-1];
        }
        // 清除掉 多余的末尾did
        delete authorityIssuerArray[datasetLength-1];
        // 刷新 did数组的 length值
        authorityIssuerArray.length--;
        return RETURN_CODE_SUCCESS;
    }

    // 获取did数组的length值
    function getDatasetLength() 
        public 
        constant 
        returns (uint) 
    {
        return authorityIssuerArray.length;
    }

    // 根据 did数组的索引获取 did
    function getAuthorityIssuerFromIndex(
        uint index
    ) 
        public 
        constant 
        returns (address) 
    {
        return authorityIssuerArray[index];
    }


    // 获取对应did的 name和创建时的timestamp
    function getAuthorityIssuerInfoNonAccValue(
        address addr
    )
        public
        constant
        returns (bytes32[16], int[16])
    {
        bytes32[16] memory allBytes32;
        int[16] memory allInt;
        for (uint index = 0; index < 16; index++) {
            allBytes32[index] = authorityIssuerMap[addr].attribBytes32[index];
            allInt[index] = authorityIssuerMap[addr].attribInt[index];
        }
        return (allBytes32, allInt);
    }

    // 获取对应did的 accValue
    function getAuthorityIssuerInfoAccValue(
        address addr
    ) 
        public 
        constant 
        returns (bytes) 
    {
        return authorityIssuerMap[addr].accValue;
    }


    // 判断 权威发行人的 name 是否已经存在
    function isNameDuplicate(
        bytes32 name
    )
        public
        constant
        returns (bool) 
    {
        // 判断 name 查出来的 did 是否为空
        if (uniqueNameMap[name] == address(0x0)) {
            return false;
        }
        return true;
    }


    // 根据 name 获取 did
    function getAddressFromName(
        bytes32 name
    )
        public
        constant
        returns (address)
    {
        return uniqueNameMap[name];
    }
}