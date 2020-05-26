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
 * @title CommitteeMemberData
 * CommitteeMember data contract.
 */

// 委员会 数据合约
contract CommitteeMemberData {

    // 一些状态码
    uint constant private RETURN_CODE_SUCCESS = 0;
    uint constant private RETURN_CODE_FAILURE_ALREADY_EXISTS = 500251;
    uint constant private RETURN_CODE_FAILURE_NOT_EXIST = 500252;

    // 委员会成员Addr数组
    address[] private committeeMemberArray;
    // 权限控制合约
    RoleController private roleController;

    // 构造函数
    function CommitteeMemberData(address addr) public {
        roleController = RoleController(addr);
    }

    // 判断某个addr是否是委员会成员
    function isCommitteeMember(
        address addr
    ) 
        public 
        constant 
        returns (bool) 
    {
        // Use LOCAL ARRAY INDEX here, not the RoleController data.
        // The latter one might lose track in the fresh-deploy or upgrade case.
        for (uint index = 0; index < committeeMemberArray.length; index++) {
            if (committeeMemberArray[index] == addr) {
                return true;
            }
        }
        return false;
    }


    // 添加委员会成员
    function addCommitteeMemberFromAddress(
        address addr  // 委员会成员 WeId
    ) 
        public
        returns (uint)
    {

        // 是否已经存在
        if (isCommitteeMember(addr)) {
            return RETURN_CODE_FAILURE_ALREADY_EXISTS;
        }
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_COMMITTEE())) {
            return roleController.RETURN_CODE_FAILURE_NO_PERMISSION();
        }

        // 给 当前 WeId 添加 委员会角色
        roleController.addRole(addr, roleController.ROLE_COMMITTEE());
        committeeMemberArray.push(addr);
        return RETURN_CODE_SUCCESS;
    }

    // 删除委员会成员
    function deleteCommitteeMemberFromAddress(
        address addr
    ) 
        public
        returns (uint)
    {
        if (!isCommitteeMember(addr)) {
            return RETURN_CODE_FAILURE_NOT_EXIST;
        }
        if (!roleController.checkPermission(tx.origin, roleController.MODIFY_COMMITTEE())) {
            return roleController.RETURN_CODE_FAILURE_NO_PERMISSION();
        }
        roleController.removeRole(addr, roleController.ROLE_COMMITTEE());
        uint datasetLength = committeeMemberArray.length;
        for (uint index = 0; index < datasetLength; index++) {
            if (committeeMemberArray[index] == addr) {break;}
        }
        if (index != datasetLength-1) {
            committeeMemberArray[index] = committeeMemberArray[datasetLength-1];
        }
        delete committeeMemberArray[datasetLength-1];
        committeeMemberArray.length--;
        return RETURN_CODE_SUCCESS;
    }


    // 获取当前 委员会成员Addr个数
    function getDatasetLength() 
        public 
        constant 
        returns (uint) 
    {
        return committeeMemberArray.length;
    }

    // 根据索引获取委员会成员addr
    function getCommitteeMemberAddressFromIndex(
        uint index
    ) 
        public 
        constant 
        returns (address) 
    {
        return committeeMemberArray[index];
    }
}