pragma solidity ^0.4.4;
/*
 *       Copyright© (2018) WeBank Co., Ltd.
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

// todo 这个是 WeId合约 【十分关键】
contract WeIdContract {

    //权限合约
    RoleController private roleController;

    // todo 存储某个 identity 变更 document 时的 blockNumber
    // (identity => block.number)
    mapping(address => uint) changed;

    modifier onlyOwner(address identity, address actor) {
        // 只有 identity 是 actor时才可以操作, 这里的actor 我们常取 msg.sender
        require (actor == identity);
        _;
    }

    // 存储在 event 中的 key??
    //
    // 这个是  document 的key
    bytes32 constant private WEID_KEY_CREATED = "created";
    // 这个是权限的key??
    bytes32 constant private WEID_KEY_AUTHENTICATION = "/weId/auth";

    // Constructor - Role controller is required in delegate calls
    //
    // todo 构造函数 - 委托调用中需要角色控制器
    function WeIdContract(
        address roleControllerAddress
    )
        public
    {
        roleController = RoleController(roleControllerAddress);
    }

    // weid的 属性变更event  todo 主要放置 Document 的各个字段值
    // todo  形成 event 链, 可以方便 后续热拓展 Document的字段
    // 当还原一个 Document 时候, 我们并不需要知道该 Document 有几个字段的值, 我们只需要从event 两边从后往前找,
    // 找出之前放置到 event 中的 Document 的各个字段, 由SDK去保证 Document 各个字段的最新值

    // 给对应的identity设置 属性 (Document 的各个字段)
    //
    // SET PubKey时                     key: /weId/pubkey/{publicKeyTypeName}/base64       | value: {publicKey}/{owner}
    // SET Authentication时             key: /weId/auth                                    | value: {publicKey}/{owner}
    // SET Service时                    key: /weId/service/{serviceType}                   | value: {serviceEndpoint} (就是个URL)
    // SET ...
    //

    event WeIdAttributeChanged(
        address indexed identity,
        bytes32 key,
        bytes value,
        uint previousBlock, // 存放上一个 块高
        int updated
    );

    // 获取关联当前 identity 的最后一个blockNumber
    function getLatestRelatedBlock(
        address identity
    ) 
        public 
        constant 
        returns (uint) 
    {
        return changed[identity];
    }

    // 变更 identity 的相关信息
    //
    // 下列参数说明, 均取自 sdk源码剖析
    //
    // todo 注意, 在创建时 是制定可一个 auth 的哦
    function createWeId(
        address identity,   // did 其实是下面 publicKey生成的address
        bytes auth,         // auth: publicKey/weAddress
        bytes created,      // 创建时的 TimeStamp
        int updated         // 更新或者创建时的 TimeStamp
    )
        public
        onlyOwner(identity, msg.sender)
    {
        // todo 使用 event 的形式存储

        // 存储 identity 的创建 timestamp 和 blockNumber 等信息 create
        WeIdAttributeChanged(identity, WEID_KEY_CREATED, created, changed[identity], updated);
        // 存储 identity 的 publicKey和address 信息  auth
        WeIdAttributeChanged(identity, WEID_KEY_AUTHENTICATION, auth, changed[identity], updated);

        // 没有  pubkey
        // 存储最会一次变更 identity的blockNumber
        changed[identity] = block.number;
    }

    // 委托创建  identity
    // todo 注意, 在创建时 是制定可一个 auth 的哦
    function delegateCreateWeId(
        address identity,     // did 其实是下面 publicKey生成的address
        bytes auth,           // auth: publicKey/weAddress
        bytes created,        // 创建时的 TimeStamp
        int updated           // 更新或者创建时的 TimeStamp
    )
        public
    {

        // 首先校验下, 当前 msg.sender 是否具备 权限

        // 校验下是否有权限修改 权威发行者
        // todo 由此可知, 权威发行者注册 DID 只能是由别人帮忙注册, 如 admin 成员或者 委员会成员来指定 权威发行者的 DID
        if (roleController.checkPermission(msg.sender, roleController.MODIFY_AUTHORITY_ISSUER())) {

            // 存储 identity 的创建 timestamp 和 blockNumber 等信息
            // Event(weId, key, value, preBlockNumber, time)
            WeIdAttributeChanged(identity, WEID_KEY_CREATED, created, changed[identity], updated);
            // 存储 identity 的 publicKey和address 信息
            WeIdAttributeChanged(identity, WEID_KEY_AUTHENTICATION, auth, changed[identity], updated);
            // 存储最会一次变更 identity的blockNumber
            changed[identity] = block.number;
        }
    }

    // 给对应的identity设置 属性 (Document 的各个字段)
    //
    // SET PubKey时                     key: /weId/pubkey/{publicKeyTypeName}/base64       | value: {pubKey}/{owner}
    // SET Authentication时             key: /weId/auth                                    | value: {publicKey}/{owner}
    // SET Service时                    key: /weId/service/{serviceType}                   | value: {serviceEndpoint} (就是个URL)
    // SET ...
    //
    function setAttribute(
        address identity,   // did, 其实就是个address
        bytes32 key,        // 举个例子, setPubKey的时候, attributeKey = /weId/pubkey/publicKeyTypeName/base64
        bytes value,        // 举个例子, setPubKey的时候, attrValue = pubKey/owner  这里的owner 可能是pubKey的owner或者就是DID
        int updated         // 当前 timestamp
    ) 
        public 
        onlyOwner(identity, msg.sender)
    {

        // 记录 identity key变更 event
    	WeIdAttributeChanged(identity, key, value, changed[identity], updated);

        // 记录下最后一次变更identity的块高
        changed[identity] = block.number;
    }

    // 委托 给对应的identity设置 属性
    function delegateSetAttribute(
        address identity,           // did, 其实就是个address
        bytes32 key,                // 举个例子, setPubKey的时候, attributeKey = /weId/pubkey/publicKeyTypeName/base64
        bytes value,                // 举个例子, setPubKey的时候, attrValue = pubKey/owner  这里的owner 可能是pubKey的owner或者就是DID
        int updated                 // 当前 timestamp
    )
        public
    {

        // admin 代理设置 权威发行人的 pubKey
        if (roleController.checkPermission(msg.sender, roleController.MODIFY_AUTHORITY_ISSUER())) {

            // 记录 identity key变更 event
            WeIdAttributeChanged(identity, key, value, changed[identity], updated);

            // 记录下最后一次变更identity的块高
            changed[identity] = block.number;
        }
    }

    // 判断 identity是否已经存在
    function isIdentityExist(
        address identity
    ) 
        public 
        constant 
        returns (bool) 
    {
        if (0x0 != identity && 0 != changed[identity]) {
            return true;
    }
        return false;
    }
}
