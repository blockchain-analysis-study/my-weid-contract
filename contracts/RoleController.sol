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

/**
 * @title RoleController
 *  This contract provides basic authentication control which defines who (address)
 *  belongs to what specific role and has what specific permission.
 */

// todo 权限控制合约
contract RoleController {

    /**
     * The universal NO_PERMISSION error code.
     */
    // 通用NO_PERMISSION错误代码 (不被允许)
    uint constant public RETURN_CODE_FAILURE_NO_PERMISSION = 500000;

    /**
     * Role related Constants.
     */
    // 一些角色

    // 权威发行人 角色
    uint constant public ROLE_AUTHORITY_ISSUER = 100;
    // 委员会成员 角色
    uint constant public ROLE_COMMITTEE = 101;
    // admin成员 角色
    uint constant public ROLE_ADMIN = 102;

    /**
     * Operation related Constants.
     */
    // 一些操作

    // 是否具备更改 权威发行人信息
    uint constant public MODIFY_AUTHORITY_ISSUER = 200;
    // 是否具备更改 委员会成员信息
    uint constant public MODIFY_COMMITTEE = 201;
    // 是否具备更改 admin成员信息
    uint constant public MODIFY_ADMIN = 202;
    // 是否具备更改 CPT模板信息
    uint constant public MODIFY_KEY_CPT = 203;

    // 权威发行者 角色承载者
    mapping (address => bool) private authorityIssuerRoleBearer;
    // 委员会成员 角色承担者
    mapping (address => bool) private committeeMemberRoleBearer;
    // 管理员 角色承载者
    mapping (address => bool) private adminRoleBearer;

    // todo 无入参 构造函数
    function RoleController() public {
        authorityIssuerRoleBearer[msg.sender] = true;
        adminRoleBearer[msg.sender] = true;
        committeeMemberRoleBearer[msg.sender] = true;
    }

    /**
     * Public common checkPermission logic.
     */
    // 公共通用的checkPermission逻辑。 todo 校验是否被允许
    function checkPermission(
        address addr,       // 某个账户或者 DID
        uint operation      // 本次操作动作
    ) 
        public 
        constant 
        returns (bool) 
    {

        // 如果本次操作是 修改 权威发行者
        if (operation == MODIFY_AUTHORITY_ISSUER) {

            // 只有 admin 或者 委员会的成员才可以操作
            if (adminRoleBearer[addr] || committeeMemberRoleBearer[addr]) {
                return true;
            }
        }

        // 如果本次操作是 修改委员会成员
        if (operation == MODIFY_COMMITTEE) {

            // 只有是 admin成员才可以操作
            if (adminRoleBearer[addr]) {
                return true;
            }
        }

        // 如果本次操作是 修改 admin成员
        if (operation == MODIFY_ADMIN) {

            // 只有 admin 成员才可以修改 admin 成员
            if (adminRoleBearer[addr]) {
                return true;
            }
        }


        // 如果是修改 CPT 模板信息
        if (operation == MODIFY_KEY_CPT) {

            // 只有权威发行者才可以修改

            // admin 和 委员会成员都不行
            if (authorityIssuerRoleBearer[addr]) {
                return true;
            }
        }
        return false;
    }

    /**
     * Add Role.
     */
    // 给addr 添加 角色信息
    function addRole(
        address addr,   // 某些账户 或者 DID
        uint role       // 角色常量, ROLE_AUTHORITY_ISSUER, ROLE_COMMITTEE, ROLE_ADMIN
    ) 
        public 
    {

        // 如果当前 设置的角色是 权威发行者的话
        if (role == ROLE_AUTHORITY_ISSUER) {
            if (checkPermission(tx.origin, MODIFY_AUTHORITY_ISSUER)) {
                authorityIssuerRoleBearer[addr] = true;
            }
        }

        // 如果当前 设置的角色是 委员会成员的话
        if (role == ROLE_COMMITTEE) {
            if (checkPermission(tx.origin, MODIFY_COMMITTEE)) {
                committeeMemberRoleBearer[addr] = true;
            }
        }

        // 如果当前 设置的角色是 admin成员的话
        if (role == ROLE_ADMIN) {
            if (checkPermission(tx.origin, MODIFY_ADMIN)) {
                adminRoleBearer[addr] = true;
            }
        }
    }

    /**
     * Remove Role.
     */
    // 给addr 移除 角色信息
    function removeRole(
        address addr,       // 某些账户 或者 DID
        uint role           // 角色常量, ROLE_AUTHORITY_ISSUER, ROLE_COMMITTEE, ROLE_ADMIN
    ) 
        public 
    {
        // 如果当前 设置的角色是 权威发行者的话
        if (role == ROLE_AUTHORITY_ISSUER) {
            if (checkPermission(tx.origin, MODIFY_AUTHORITY_ISSUER)) {
                authorityIssuerRoleBearer[addr] = false;
            }
        }
        // 如果当前 设置的角色是 委员会成员的话
        if (role == ROLE_COMMITTEE) {
            if (checkPermission(tx.origin, MODIFY_COMMITTEE)) {
                committeeMemberRoleBearer[addr] = false;
            }
        }
        // 如果当前 设置的角色是 admin成员的话
        if (role == ROLE_ADMIN) {
            if (checkPermission(tx.origin, MODIFY_ADMIN)) {
                adminRoleBearer[addr] = false;
            }
        }
    }

    /**
     * Check Role.
     */
    // 给addr 校验 角色信息
    function checkRole(
        address addr,      // 某些账户 或者 DID
        uint role          // 角色常量, ROLE_AUTHORITY_ISSUER, ROLE_COMMITTEE, ROLE_ADMIN
    ) 
        public 
        constant 
        returns (bool) 
    {
        // 如果当前 设置的角色是 权威发行者的话
        if (role == ROLE_AUTHORITY_ISSUER) {
            return authorityIssuerRoleBearer[addr];
        }
        // 如果当前 设置的角色是 委员会成员的话
        if (role == ROLE_COMMITTEE) {
            return committeeMemberRoleBearer[addr];
        }
        // 如果当前 设置的角色是 admin成员的话
        if (role == ROLE_ADMIN) {
            return adminRoleBearer[addr];
        }
    }
}
