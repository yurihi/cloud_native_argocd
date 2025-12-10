package com.nds.restful_web_services.controller;

import lombok.Getter;

@Getter
public class HelloWorldBean {
    private String message;
    
    public HelloWorldBean(String message) {
        this.message = message;
    }
}
